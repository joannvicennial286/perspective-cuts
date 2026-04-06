Output demos/compile.gif

Set Shell "zsh"
Set FontSize 16
Set Width 900
Set Height 500
Set Theme "Catppuccin Mocha"
Set Padding 20

Type "cat Examples/substack-summarizer.perspective"
Enter
Sleep 3s

Type "perspective-cuts compile --sign Examples/substack-summarizer.perspective"
Enter
Sleep 2s

Type "ls -la *.shortcut"
Enter
Sleep 2s
