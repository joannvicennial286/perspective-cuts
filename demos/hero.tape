Output demos/hero.gif

Set Shell "zsh"
Set FontSize 16
Set Width 900
Set Height 500
Set Theme "Catppuccin Mocha"
Set Padding 20

Type "cat Examples/hello-world.perspective"
Enter
Sleep 2s

Type "perspective-cuts compile --sign Examples/hello-world.perspective"
Enter
Sleep 2s

Type "perspective-cuts actions | head -20"
Enter
Sleep 3s

Type "perspective-cuts discover openai"
Enter
Sleep 3s
