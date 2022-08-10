
注意：为了使得名字颜色改变，大部分插件都与getoverit.sp有联动，没有这个插件，其它插件可能需要修改才能正常工作。
## nmrih_dif.sp

投票更改模式、难度、密度，以及开启、关闭无限体力、出生自带砍刀。
## chat-processor.sp
https://forums.alliedmods.net/showthread.php?p=2448733

进行了优化

依赖项，其它插件需要。
## nameprocess.sp
https://forums.alliedmods.net/showthread.php?p=738756

加入服务器会显示玩家国家信息

利用chat-processor，说话时会自动在名字加上死亡、撤离信息，以及国家信息

同时，依靠globalvariables.sp，对消息进行处理，可以扩展颜色和一些变量（如{time24}、{date}

## globalvariables.sp

提供了CPrintxxx的native函数，以及转义一些变量的native方法（CProcessVaribles）

## ctop.sp
https://forums.alliedmods.net/showthread.php?p=2732929

通关时间记录插件，需要翻译文本，在上层目录的translations文件夹。

会观察sm_inf_stamina, sm_machete_enable, sm_gamemode, sv_spawn_density, sv_difficulty的值，判断停止通关记录

假如地图开始时（OnConfigExecuted之前）就设置了这些参数不符合开启通关记录的要求，则后续会忽略这些参数。（比如在mapconfigs设置了无限体力，则游玩时无限体力不会影响通关记录的开启）

修改为sqlite数据库，并根据 sm_pk_mode 的值，会有不同的计时办法：
- sm_pk_mode为0，从最初的出生点开始计时，第一个人撤离时结束计时，一轮游戏中所有人的时间记录都一样。
- sm_pk_mode为1，每人的计时都是从出生到撤离，适合跑酷图。

添加!wrn命令以击杀数量排序显示记录

## getoverit.sp
特色插件，根据撤离次数改变名字颜色。

## HUD.sp
ui插件，需要翻译文本。

!speed开启/关闭速度显示；

sm_speedmeter参数开启后，UI更新频率大幅加快，且去除耐力、状态显示，适合连跳、滑翔；
观战时能看到观战同一对象的人；

## mapconfigs.sp
不同的地图套用不同参数

修改：没有适用的配置文件时会套用 default.cfg 的配置。

## networking.sp
限制死人网络速率，节省带宽，实际基本**没有**效果
## nmrih_ibn.sp
https://forums.alliedmods.net/showthread.php?p=2335718

流血、感染提示，需要翻译文本。
## nmrih_infinity.sp
https://forums.alliedmods.net/showthread.php?p=2287730

无限体力、弹药插件

修改：!inf投票开关无限体力。无限弹药需要自行修改参数开启。

## obj_translator.sp
地图任务翻译

兼容 NMRiH Objective Multilingual 的翻译文本，gametxt实现了多语言。另外，管理员可使用!trans命令在游戏中翻译任务。

## randomsupply.sp
出生自带武器、补给

## test.sp
测试插件，命令!count显示僵尸数量，!make+数字 刷一定数量的跑尸

## VoiceMessageProcess.sp
改变语音消息在聊天框的文本，插件只改变了文本颜色

## reconnect
掉线重连

需要翻译文本和gamedata

## mark
标记

## advertisements
定时显示服务器信息

advertisements.txt和原版不一样

## rtv
当轮游戏有人撤离，则下轮开始时自动开启rtv

## basecommands, basevote, mapchooser, nextmap, nominations
优化载入速度

只需mapchooser读取地图列表，其他插件仅调用，由于mapchooser读取数据很多，需要调高sourcemod的SlowScriptTimeout参数（core.cfg）