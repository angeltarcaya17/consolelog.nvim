local M = {}

local bit = require("bit")

-- Pure Lua SHA1 implementation for WebSocket handshake
function M.sha1(msg)
	local h0 = 0x67452301
	local h1 = 0xEFCDAB89
	local h2 = 0x98BADCFE
	local h3 = 0x10325476
	local h4 = 0xC3D2E1F0
	
	local function f(t, b, c, d)
		if t < 20 then
			return bit.bor(bit.band(b, c), bit.band(bit.bnot(b), d))
		elseif t < 40 then
			return bit.bxor(bit.bxor(b, c), d)
		elseif t < 60 then
			return bit.bor(bit.bor(bit.band(b, c), bit.band(b, d)), bit.band(c, d))
		else
			return bit.bxor(bit.bxor(b, c), d)
		end
	end
	
	local function k(t)
		if t < 20 then
			return 0x5A827999
		elseif t < 40 then
			return 0x6ED9EBA1
		elseif t < 60 then
			return 0x8F1BBCDC
		else
			return 0xCA62C1D6
		end
	end
	
	-- Padding
	local msgLen = #msg
	local padLen = (55 - msgLen) % 64
	local padded = msg .. string.char(0x80) .. string.rep(string.char(0), padLen)
	
	-- Add length in bits as 64-bit big-endian
	local lenBits = msgLen * 8
	padded = padded .. string.char(
		0, 0, 0, 0,
		bit.band(bit.rshift(lenBits, 24), 0xFF),
		bit.band(bit.rshift(lenBits, 16), 0xFF),
		bit.band(bit.rshift(lenBits, 8), 0xFF),
		bit.band(lenBits, 0xFF)
	)
	
	-- Process each 512-bit chunk
	for i = 1, #padded, 64 do
		local chunk = padded:sub(i, i + 63)
		local w = {}
		
		-- Break chunk into 16 32-bit words
		for j = 1, 16 do
			local idx = (j - 1) * 4 + 1
			w[j - 1] = bit.bor(
				bit.lshift(chunk:byte(idx), 24),
				bit.lshift(chunk:byte(idx + 1), 16),
				bit.lshift(chunk:byte(idx + 2), 8),
				chunk:byte(idx + 3)
			)
		end
		
		-- Extend to 80 words
		for j = 16, 79 do
			w[j] = bit.rol(bit.bxor(bit.bxor(bit.bxor(w[j - 3], w[j - 8]), w[j - 14]), w[j - 16]), 1)
		end
		
		local a, b, c, d, e = h0, h1, h2, h3, h4
		
		for j = 0, 79 do
			local temp = bit.band(bit.rol(a, 5) + f(j, b, c, d) + e + w[j] + k(j), 0xFFFFFFFF)
			e = d
			d = c
			c = bit.rol(b, 30)
			b = a
			a = temp
		end
		
		h0 = bit.band(h0 + a, 0xFFFFFFFF)
		h1 = bit.band(h1 + b, 0xFFFFFFFF)
		h2 = bit.band(h2 + c, 0xFFFFFFFF)
		h3 = bit.band(h3 + d, 0xFFFFFFFF)
		h4 = bit.band(h4 + e, 0xFFFFFFFF)
	end
	
	-- Return as binary string
	local result = string.char(
		bit.rshift(h0, 24), bit.band(bit.rshift(h0, 16), 0xFF), bit.band(bit.rshift(h0, 8), 0xFF), bit.band(h0, 0xFF),
		bit.rshift(h1, 24), bit.band(bit.rshift(h1, 16), 0xFF), bit.band(bit.rshift(h1, 8), 0xFF), bit.band(h1, 0xFF),
		bit.rshift(h2, 24), bit.band(bit.rshift(h2, 16), 0xFF), bit.band(bit.rshift(h2, 8), 0xFF), bit.band(h2, 0xFF),
		bit.rshift(h3, 24), bit.band(bit.rshift(h3, 16), 0xFF), bit.band(bit.rshift(h3, 8), 0xFF), bit.band(h3, 0xFF),
		bit.rshift(h4, 24), bit.band(bit.rshift(h4, 16), 0xFF), bit.band(bit.rshift(h4, 8), 0xFF), bit.band(h4, 0xFF)
	)
	
	return result
end

-- Base64 encoding
function M.base64_encode(data)
	local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	return ((data:gsub('.', function(x)
		local r, b = '', x:byte()
		for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0') end
		return r
	end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
		if (#x < 6) then return '' end
		local c = 0
		for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
		return b:sub(c + 1, c + 1)
	end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

return M