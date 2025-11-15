(function() {
    const VLQ_BASE_SHIFT = 5;
    const VLQ_BASE = 1 << VLQ_BASE_SHIFT;
    const VLQ_BASE_MASK = VLQ_BASE - 1;
    const VLQ_CONTINUATION_BIT = VLQ_BASE;
    
    const BASE64_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    const BASE64_MAP = {};
    for (let i = 0; i < BASE64_CHARS.length; i++) {
      BASE64_MAP[BASE64_CHARS[i]] = i;
    }
    
    const sourceMapCache = new Map();
    const urlCache = new Map();
    const chunkIndex = new Map();
    let isIndexBuilt = false;
    
    function decodeVLQ(str, index) {
      let result = 0;
      let shift = 0;
      let continuation = true;
      
      while (continuation) {
        if (index >= str.length) {
          throw new Error('Unexpected end of VLQ');
        }
        
        const digit = BASE64_MAP[str[index++]];
        if (digit === undefined) {
          throw new Error('Invalid base64 digit: ' + str[index - 1]);
        }
        
        continuation = (digit & VLQ_CONTINUATION_BIT) !== 0;
        result += (digit & VLQ_BASE_MASK) << shift;
        shift += VLQ_BASE_SHIFT;
      }
      
      const shouldNegate = (result & 1) === 1;
      result = result >> 1;
      
      return {
        value: shouldNegate ? -result : result,
        index: index
      };
    }
    
    function parseSourceMapMappings(mappings) {
      const decodedMappings = [];
      let generatedLine = 0;
      let previousGeneratedColumn = 0;
      let previousOriginalLine = 0;
      let previousOriginalColumn = 0;
      let previousSource = 0;
      
      const lines = mappings.split(';');
      
      for (let i = 0; i < lines.length; i++) {
        generatedLine++;
        previousGeneratedColumn = 0;
        
        const segments = lines[i].split(',');
        
        for (const segment of segments) {
          if (!segment) continue;
          
          let index = 0;
          const mapping = { generatedLine, generatedColumn: 0 };
          
          const genColDecode = decodeVLQ(segment, index);
          previousGeneratedColumn += genColDecode.value;
          mapping.generatedColumn = previousGeneratedColumn;
          index = genColDecode.index;
          
          if (index >= segment.length) {
            decodedMappings.push(mapping);
            continue;
          }
          
          const sourceDecode = decodeVLQ(segment, index);
          previousSource += sourceDecode.value;
          mapping.source = previousSource;
          index = sourceDecode.index;
          
          if (index >= segment.length) {
            decodedMappings.push(mapping);
            continue;
          }
          
          const origLineDecode = decodeVLQ(segment, index);
          previousOriginalLine += origLineDecode.value;
          mapping.originalLine = previousOriginalLine + 1;
          index = origLineDecode.index;
          
          if (index >= segment.length) {
            decodedMappings.push(mapping);
            continue;
          }
          
          const origColDecode = decodeVLQ(segment, index);
          previousOriginalColumn += origColDecode.value;
          mapping.originalColumn = previousOriginalColumn;
          
          decodedMappings.push(mapping);
        }
      }
      
      return decodedMappings;
    }
    
    function findOriginalPosition(mappings, line, column) {
      let bestMatch = null;
      let bestDistance = Infinity;
      
      for (const mapping of mappings) {
        if (mapping.generatedLine !== line) continue;
        if (!mapping.hasOwnProperty('originalLine')) continue;
        
        const distance = Math.abs(mapping.generatedColumn - column);
        
        if (mapping.generatedColumn <= column && distance < bestDistance) {
          bestDistance = distance;
          bestMatch = mapping;
        }
      }
      
      return bestMatch;
    }
    
    async function buildChunkIndex() {
      if (isIndexBuilt || typeof performance === 'undefined') return;
      
      const chunks = performance.getEntriesByType('resource')
        .filter(r => r.name.includes('.js') || r.name.includes('.jsx') || r.name.includes('.ts') || r.name.includes('.tsx'))
        .filter(r => !r.name.includes('node_modules'))
        .map(r => r.name);
      
      for (const chunkUrl of chunks) {
        try {
          const response = await fetch(chunkUrl);
          if (!response.ok) continue;
          
          const code = await response.text();
          const regex = /\/\/# sourceMappingURL=data:application\/json;(?:charset=utf-8;)?base64,([A-Za-z0-9+/=]+)/g;
          let match;
          
          while ((match = regex.exec(code))) {
            try {
              const json = atob(match[1]);
              const sourceMap = JSON.parse(json);
              
              if (sourceMap.sources) {
                sourceMap.sources.forEach(source => {
                  const normalized = normalizeSourcePath(source);
                  if (normalized) {
                    if (!chunkIndex.has(normalized)) {
                      chunkIndex.set(normalized, []);
                    }
                    chunkIndex.get(normalized).push({
                      chunkUrl,
                      sourceMap
                    });
                  }
                });
              }
            } catch (e) {}
          }
        } catch (e) {}
      }
      
      isIndexBuilt = true;
    }

    async function findChunkForSource(targetFile) {
      if (!isIndexBuilt) {
        await buildChunkIndex();
      }
      
      const normalizedTarget = normalizeSourcePath(targetFile);
      if (!normalizedTarget) return null;
      
      const fileName = normalizedTarget.split('/').pop();
      
      if (chunkIndex.has(normalizedTarget)) {
        const chunks = chunkIndex.get(normalizedTarget);
        if (chunks && chunks.length > 0) {
          return chunks[0];
        }
      }
      
      for (const [source, chunks] of chunkIndex.entries()) {
        if (source.endsWith('/' + fileName) || source === fileName) {
          if (chunks && chunks.length > 0) {
            return chunks[0];
          }
        }
      }
      
      return null;
    }

    async function fetchSourceMap(url, targetFile) {
      const cacheKey = url + (targetFile ? '#' + targetFile : '');
      if (sourceMapCache.has(cacheKey)) {
        return sourceMapCache.get(cacheKey);
      }
      
      try {
        let response;
        let code;
        
        try {
          response = await fetch(url);
          if (!response.ok) {
            sourceMapCache.set(cacheKey, null);
            return null;
          }
          code = await response.text();
        } catch (fetchError) {
          sourceMapCache.set(cacheKey, null);
          return null;
        }
        
        const regex = /\/\/# sourceMappingURL=data:application\/json;(?:charset=utf-8;)?base64,([A-Za-z0-9+/=]+)/g;
        let match;
        let foundSourceMap = null;
        
        while ((match = regex.exec(code))) {
          try {
            const json = atob(match[1]);
            const sourceMap = JSON.parse(json);
            
            if (targetFile) {
              const hasTargetFile = sourceMap.sources && sourceMap.sources.some(src => {
                const fileName = targetFile.split('/').pop();
                return src.includes(targetFile) || src.includes(fileName);
              });
              
              if (hasTargetFile) {
                foundSourceMap = sourceMap;
                break;
              }
            } else {
              foundSourceMap = sourceMap;
              break;
            }
          } catch (parseError) {
            continue;
          }
        }
        
        if (foundSourceMap) {
          sourceMapCache.set(cacheKey, foundSourceMap);
          return foundSourceMap;
        }
        
        sourceMapCache.set(cacheKey, null);
        return null;
      } catch (e) {
        sourceMapCache.set(cacheKey, null);
        return null;
      }
    }
    
    function normalizeSourcePath(sourcePath) {
      if (!sourcePath) return null;
      
      let normalized = sourcePath;
      
      if (normalized.includes('://')) {
        normalized = normalized.replace(/^[^:]+:\/\/[^/]*\//, '');
      }
      
      normalized = normalized.replace(/^@fs\//, '');
      
      normalized = normalized.replace(/^(\.\.?\/)+/, '');
      
      normalized = normalized.replace(/[?#].*$/, '');
      
      normalized = normalized.replace(/\\/g, '/');
      normalized = normalized.replace(/^[A-Z]:\//, '');
      
      normalized = normalized.replace(/^\/+/, '');
      
      if (normalized.startsWith('webpack/')) return null;
      if (normalized.startsWith('(webpack)')) return null;
      if (normalized.includes('/node_modules/')) return null;
      if (normalized.includes('webpack/runtime')) return null;
      
      const parts = normalized.split('/');
      for (let i = 0; i < parts.length; i++) {
        if (parts[i] === 'app' || parts[i] === 'pages' || parts[i] === 'src') {
          return parts.slice(i).join('/');
        }
      }
      
      return normalized || null;
    }
 
    window.__consolelogSourceMapResolver = {
      async resolveLocation(location) {
        if (!location || !location.url) return location;
        
        const url = location.url;
        
        let fetchUrl = null;
        let targetFile = null;
        
        if (url.includes('webpack-internal://')) {
          const parts = url.split('/./');
          if (parts.length > 1) {
            targetFile = parts[1].split(':')[0].split('?')[0];
          }
          
          const chunkInfo = await findChunkForSource(targetFile);
          if (chunkInfo) {
            fetchUrl = chunkInfo.chunkUrl;
          }
        } else if (url.includes('webpack://')) {
          const urlParts = url.split('webpack://');
          if (urlParts[1]) {
            fetchUrl = window.location.origin + '/' + urlParts[1];
          }
        } else if (url.includes('_next/static')) {
          fetchUrl = url;
        } else if (!url.includes('localhost') && 
            !url.includes('127.0.0.1') && 
            !url.match(/:\d+\//)) {
          return location;
        } else {
          fetchUrl = url;
        }
        
        if (!fetchUrl) {
          return location;
        }
        
        if (urlCache.has(fetchUrl)) {
          fetchUrl = urlCache.get(fetchUrl);
        }
        
        const sourceMap = await fetchSourceMap(fetchUrl, targetFile);
        if (!sourceMap) {
          return location;
        }
        
        
        const mappings = parseSourceMapMappings(sourceMap.mappings);
        const original = findOriginalPosition(mappings, location.line, location.column || 0);
        
        
        if (!original || !original.originalLine) {
          return location;
        }
        
        const sourceFile = sourceMap.sources[original.source];
        const normalizedFile = normalizeSourcePath(sourceFile);
        
        
        if (!normalizedFile) {
          return location;
        }
        
        const result = {
          file: normalizedFile,
          line: original.originalLine,
          column: original.originalColumn || 0,
          url: url,
          originalUrl: url,
          confidence: 0.95,
          sourceMapped: true
        };
        
        return result;
      },
      
      clearCache() {
        sourceMapCache.clear();
        urlCache.clear();
        chunkIndex.clear();
        isIndexBuilt = false;
      }
    };
    
    if (typeof window !== 'undefined' && window.addEventListener) {
      window.addEventListener('load', () => {
        setTimeout(() => buildChunkIndex(), 100);
      });
    }
  })();
