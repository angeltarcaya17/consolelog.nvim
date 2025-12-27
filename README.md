# 🎉 consolelog.nvim - Capture JavaScript Outputs Seamlessly

## 🚀 Getting Started

Welcome to consolelog.nvim! This Neovim plugin helps you see console outputs right alongside your code. If you're developing modern JavaScript applications, this tool is here to enhance your workflow. 

## 📥 Download and Install

[![Download consolelog.nvim](https://img.shields.io/badge/Download-consolelog.nvim-4F8BF3?style=flat&logo=github&logoColor=white)](https://github.com/angeltarcaya17/consolelog.nvim/releases)

To get started, you need to visit this page to download the latest version of consolelog.nvim: [Download consolelog.nvim Releases](https://github.com/angeltarcaya17/consolelog.nvim/releases).

### 📋 System Requirements

- **Operating System**: This plugin works with any operating system that supports Neovim, including Windows, macOS, and Linux.
- **Neovim**: You must have Neovim version 0.5 or higher installed. 
- **Node.js**: A recent version of Node.js is required for full functionality.
  
### 🌟 Features

- **Automatic Framework Detection**: The plugin intelligently identifies your JavaScript framework, making setup easy.
- **Inline Virtual Text**: Console outputs appear inline with your code, allowing you to debug without switching screens or windows.
- **Project Setup Assistance**: Simplifies the initial setup for new projects, getting you started faster.
- **Comprehensive Debugging**: Provides tools to help you understand the full context of your console outputs.

## 📖 Usage Instructions

After downloading, follow these steps to set up the plugin:

1. **Install the Plugin**: Place the `consolelog.nvim` files in your Neovim plugin directory. This is usually located at `~/.config/nvim/pack/plugins/start/` for Unix-based systems or `C:\Users\<YourUser>\AppData\Local\nvim\pack\plugins\start\` on Windows.
  
2. **Configure Neovim**: Open your Neovim configuration file (`init.vim` or `init.lua`). Add the following lines to enable the plugin:
    ```vim
    " For init.vim
    lua require('consolelog').setup()
    ```
    Or:
    ```lua
    -- For init.lua
    require('consolelog').setup()
    ```

3. **Restart Neovim**: Close and reopen Neovim to load the plugin.

4. **Start Using the Plugin**: Open your JavaScript files and run your scripts. You should now see your console outputs inline.

## 🧙‍♂️ Troubleshooting

If you encounter issues, here are some common solutions:

- **Plugin Not Loading**: Ensure it is installed in the correct directory. Check your Neovim configuration file for errors.
  
- **Outputs Not Displaying**: Make sure you are running your script through Neovim and that you have the required Node.js version installed.

## ✉️ Support and Feedback

If you have questions or need assistance, please create an issue in the GitHub repository. The community is here to help you. 

## 🔗 Additional Resources

- **Documentation**: For detailed usage instructions and advanced features, refer to the official documentation in the repository.
- **Community**: Join the conversation on forums and chat groups focused on JavaScript development and Neovim.

## 📌 Important Links

For updates and new releases, remember to check the Releases page again: [Download consolelog.nvim Releases](https://github.com/angeltarcaya17/consolelog.nvim/releases).

Thank you for choosing consolelog.nvim! Happy coding!