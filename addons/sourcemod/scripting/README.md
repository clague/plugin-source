
注意：为了使得名字颜色改变，大部分插件都与getoverit.sp有联动，没有这个插件，其它插件可能需要修改才能正常工作。
## c_nmrih_diffmoder.sp
原版：https://forums.alliedmods.net/showthread.php?p=2549109

简化为仅有全跑功能，可通过参数切换默认、全跑、全小孩，每次换图会重置为全跑模式。
## chat-processor.sp
https://forums.alliedmods.net/showthread.php?p=2448733

依赖项，其它插件需要。
## countrynick.sp
https://forums.alliedmods.net/showthread.php?p=738756

加入服务器会显示国家

说话时，名字前会显示国家前缀，但并不会修改名字
## ctop.sp
https://forums.alliedmods.net/showthread.php?p=2732929

通关时间记录插件，需要翻译文本，在上层目录的translations文件夹。

修改为sqlite数据库，并根据 sm_pk_mode 的值，会有不同的计时办法：
- sm_pk_mode为0，从最初的出生点开始计时，第一个人撤离时结束计时，一轮游戏中所有人的时间记录都一样。
- sm_pk_mode为1，每人的计时都是从出生到撤离，适合跑酷图。

添加!wrn命令以击杀数量排序显示记录
## getoverit.sp
特色插件，根据撤离次数改变名字颜色。

## health_and_stamina_disp.sp
https://forums.alliedmods.net/showthread.php?p=2667936

ui插件，需要翻译文本。
改进：删掉蓄力伤害显示，解决地图文本冲突。
## mapconfigs.sp
不同的地图套用不同参数

修改：没有适用的配置文件时会套用 default.cfg 的配置。
## music.sp
点歌插件，需要扩展

由于游戏更新，motd无法显示网页，暂未测试是无法加载还是加载但不显示
## networking.sp
限制死人网络速率，节省带宽，实际基本没有效果
## nmrih_ibn.sp
https://forums.alliedmods.net/showthread.php?p=2335718

流血、感染提示，需要翻译文本。
## nmrih_infinity.sp
https://forums.alliedmods.net/showthread.php?p=2287730

无限体力、弹药插件

修改：与记录插件联动，无限体力情况下不会记录通关。!inf投票开关无限体力。无限弹药需要修改参数开启。

## obj_translator.sp
地图任务翻译

兼容 NMRiH Objective Multilingual 的翻译文本，gametxt实现了多语言。另外，管理员可使用!trans命令在游戏中翻译任务。

## respawn_with_random_supply.sp
出生自带武器、补给

## test.sp
测试插件，命令!count显示僵尸数量，!make+数字 刷一定数量的跑尸

## VoiceMessageProcess.sp
改变语音消息在聊天框的文本，插件只改变了文本颜色
