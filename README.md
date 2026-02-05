# screenshotTool  
hyprland quickshell screenshot tool for myself  

- dependencies : `quickshell swappy wl-clipboard`  

cr: https://github.com/caelestia-dots/shell for quickshell codes  
### similar/identical style to caelestia but as an independent screenshot tool for hyprland  
usage  
add `exec-once = qs -c screenshotTool -d` to Hyprland execs,  
example keybinds:  
```
bind = Super+Shift, S, exec, qs -c screenshotTool ipc call picker openFreezeClip
bind = Super+Shift+Alt, S, exec, qs -c screenshotTool ipc call picker openFreeze
```
available options:  
  openFreezeClip : open and freeze screen for screenshot and copies to clipboard  
  openFreeze : open and freeze screen for screenshot and pipes to swappy  
  openClip : open and **don't** freeze screen for screenshot and copies to clipboard  
  open : open and **don't** freeze screen for screenshot and pipes to swappy  
