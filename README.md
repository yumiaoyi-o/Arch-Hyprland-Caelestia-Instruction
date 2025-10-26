#Arch-Hyprland-quickshell初学者指南
-----
Step 1  准备系统盘iso文件，已经格式化了的移动硬盘
Step 2 uefi 启动系统盘，开始安装系统
Step3 usb联网
Step4 更新时间
```
timedatectl set-ntp true
```
Step5 磁盘分区
```
cfdisk /dev/sdx
#清除所有可能存在的内容
[Delete]
#创建efi分区 
[New] 1g [Type]  # 选择最上面的efi分区 
#创建根目录
[New] enter [write] yes
#退出
[Quit]
```
Step6 格式化分区
```
#启动分区
mkfs.fat -F 32 /dev/sdx1
#根分区
mkfs.btrfs /dev/sda2
```
Step7 创建btrfs根分区子卷
```
#挂载根分区
mount -t btrfs -o compress=zstd /dev/sda2 /mnt
#创建根子卷
btrfs subvolume create /mnt/@
#创建home子卷
btrfs subvolume create /mnt/@home
#创建swap子卷
btrfs subvolume create /mnt/@swap
#创建snapshots子卷
btrfs subvolume create /mnt/@snapshots_root
btrfs subvolume create /mnt/@snapshots_home
#取消挂载
umount /mnt
```
Step 8 正式挂载
```
#挂载目录
mount -t btrfs -o subvol=/@,compress=zstd /dev/sda2 /mnt
#挂载home目录
mount --mkdir -t btrfs -o subvol=/@home,compress=zstd /dev/sda2 /mnt/home
#挂载swap目录
mount --mkdir -t btrfs -o subvol=/@swap,compress=zstd /dev/sda2 /mnt/swap
#挂载启动分区
mount --mkdir /dev/sda1 /mnt/boot
```
Step9 改镜像源
参考 https://mirrors.tuna.tsinghua.edu.cn/help/archlinux
Step10 更新密钥
```
pacman -Sy archlinux-keyring
```
Step11 安装内核相关文件
```
pacstrap -K /mnt base base-devel linux linux-headers linux-firmware btrfs-progs
```
Step12 安装重要工具
```
pacstrap /mnt networkmanager vim sudo intel-ucode
```
Step13 创建swap文件
```
btrfs filesystem mkswapfile --size 64g --uuid clear /mnt/swap/swapfile
swapon /mnt/swap/swapfile
genfstab -U /mnt > /mnt/etc/fstab
```
Step14 进入新系统分区
```
arch-chroot /mnt
```
Step15 设置设备
```
vim /etc/hostname
#按i输入 <你的设备名> #按esc退出编辑模式
#按：wq退出vim
#你想要什么设备名输入什么就好了
``` 
Step16 设置时区
```
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc
```
Step17 设置语言
```
vim /etc/locale.gen
按/en_US寻找en_US.UTF-8，zh_CN.UTF8行并取消注释然后退出
locale.gen
vim /etc/locale.conf
输入LANG=en_US.UTF-8
```
Step18 设置root密码
```
passwd(然后输入两次你要用的密码就好了)
```
Step19 安装grub与其他工具
```
pacman -S grub efibootmgr ifuse (解决苹果无法正常使用usb共享网络的问题，不是苹果可以不用下载)
grub-install --target=x86_64-efi --efi-directory=/boot --removable --recheck
vim /etc/default/grub
修改loglevel为“loglevel=5 nowatchdog modprobe.blacklist=iTCO_wdt"
grub-mkconfig -o /boot/grub/grub.cfg
```
Step21 退出新系统分区并重启
```
exit
reboot
```
Step22 启动后联网
```
nmtui
[activate a connection]
选择你的无线网并输入密码
```
Step23 安装小玩具
```
pacman -S fastfetch cmatrix lolcat
fastfetch | lolcat
cmatrix
cmatrix | lolcat
```
Step24 改国内源
参考https://mirrors.tuna.tsinghua.edu.cn/help/archlinuxcn,顺便在/etc/pacman.conf中去掉multilib的注释
Step25 安装yay
```
pacman -S yay
每天要yay -Syu确保软件更新
如果有时候出现下载卡住的时候记得开一下外网
```
Step25 安装显卡驱动
```
pacman -S nvidia nvidia-settings lib32-nvidia-utils
vim /etc/modprobe.d/blacklist-nouveau.conf
输入
blacklist nouveau
options nouveau modeset=0
退出
vim /etc/mkinitcpio.conf
在modules的括号里添加nvidia nvidia_modeset nvidia_uvm nvidia_drm，删除hook括号里的kms
vim /etc/modprobe.d/nvidia.conf
输入options nvidia_drm modeset=1 fbdev=1
mkinitcpio -P
reboot
```
Step26 设置非root的sudo组用户
```
useradd -m -s /bin/bash  <用户名>
passwd <用户名>
usermod -aG wheel <用户名>
vim /etc/sudoers
取消%wheel ALL=(ALL:ALL) ALL行的注释
```
Step27 安装hyprland
```
yay -Syu --devel
yay -S hyprland-git
cp -r hypr .config
hypr文件夹里面涉及到一些我在本文件夹里提供的脚本，当我让你把它们放入.local/bin里的时候不要忘记chmod +x提供执行权限
也请不要随意改我的脚本的名字，除非你知道后果以及知道怎么解决（当然是要更新一下那些调用这个脚本的地方的名字呢）
hyprland
```
Step28 snapper
```
yay -S snapper
sudo snapper -c root create-config -f btrfs /
sudo snapper -c home create-config -f btrfs /home
chmod +x */snapper_change_btrfs.sh（这里路径得看你把我这个指南里面snapper文件夹下的脚本放哪里了）
snapper_change_btrfs.sh
# 备份一次初始备份
```
step29 chrome
```
yay -S google-chrome
mkdir .local/bin
cp google-chrome-scale .local/bin
cp google-chrome.desktop .local/share/applications
chmod +x google-chrome-scale（路径问题同上）
.local/bin/google-chrome-scale
# 设为默认浏览器
```
Step30 vpn
```
yay -S clash-verge-rev
# 记得下载虚拟网卡那个开关，不然没办法科学上网
chrome去copy url 导入clash
有需要校网vpn的可以yay -S atrust-bin
然后运行atrust-fix.sh修改atrust的一些闪退问题，否则无法正常使用
将atrust-restart-clean.sh放入.local/bin
```
Step31 输入法
```
选择fcitx5
chmod +x install-fcitx5.sh
install-fcitx5.sh
即可，后续美化比较麻烦，等我更新
```
Step32 字体/font
```
运行font文件夹下的脚本可以安装苹果的emoji、中英文字体
```
Step33 vscode
```
yay -S visual-studio-code-bin
code打开
ctrl+space+'+'/'-' 缩放字号
登陆github以使用copilot
# 可以去申请github教育优惠免费用pro
cp settings.json ~/.config/Code/User
vscode-theme/vscode_extension/github 下有一个sh文件可以帮你我们最爱的安安黑粉配色主题
```
Step34 kitty
```
将kitty文件夹下的conf cp到.config/kitty下可以有vscode同款blackpink配色
```
Step35 quickshell
```
先推荐yay -S caelestia-shell,但是安装过程中会出现奇奇怪怪的问题
在你和ai沟通半天下好之后记得把caelestia文件夹下的caelestia-forceddpi复制到.local/bin里
hyprland.conf里已经弄好了caelestia开机自启的事情，中间会有一个启动然后立马杀掉进程的命令是为了让壁纸能够正常加载显示
会出现一些图标无法显示的情况，需要yay -S papirus
```
Step36 听歌
```
我选择yesplaymusic,主要是因为方便连接网易云
但是有的时候会出现开机无法启动的情况，是因为上次关机的时候进程未被正常关闭
将yesplaymusic整个文件夹复制到.local/bin里就能解决这个问题（开机自动清理之前的残留）
注意是cp -r yesplaymusic .local/bin 因为我hypr/yesplaymusic.conf里是这么写的，可以通过修改exec-once语句修改
```
至此，你已经有了一个可以正常使用的，比windows美观的arch+hyprland系统
不要忘记每天登录签到（yay -Syu）
