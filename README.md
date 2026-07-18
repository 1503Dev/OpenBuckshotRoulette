# Open Buckshot Roulette
[Github](https://github.com/1503Dev/OpenBuckshotRoulette) | [Gitee](https://gitee.com/dev1503/OpenBuckshotRoulette)

**项目正在重制中**  
*正在收拾 MIKE KLUBNIKA 和我的一些烂摊子*

这是一个把 Buckshot Roulette (恶魔轮盘) 开源并扩展的项目，基于 v2.2.0.6 (Steam)  
如果你想修改或使用 Open Buckshot Roulette 请确保 Buckshot Roulette 在你的 itch.io 或 Steam 账户上可用

你需要使用 Godot Engine 4.7 及以上版本编辑它  

多人游戏目前基本可用

## 如何提交BUG
在 [Github/Issues](https://github.com/1503Dev/OpenBuckshotRoulette/issues) 或 [Gitee/Issues](https://gitee.com/dev1503/OpenBuckshotRoulette/issues) 中新建一个议题，描述你遇到的问题，并包含你的运行信息(游戏版本、系统、机型、渲染器等)，最好是附上截图或视频，以及复现流程  

你可以在 v1.0.2.17 及以上版本的主菜单中进入选项，点击左下角的 `复制运行信息` 文字来获取标准运行信息  

欢迎所有人提交 Pull request

## 多人游戏
### 搭建服务器
```bash
cd ./buckshot-dedicated-server
npm install
node main
```

### 连接服务器
_默认已连接到 1503Dev 的在线服务器_  
主菜单 > 选项 > 在线服务 > 从剪切板粘贴服务器地址

## 模组 (实验)
Open Buckshot Roulette 提供了一个简单、轻量的模组加载器，利用了 Godot 的脚本热加载特性

### 安装模组
主菜单左下角可打开模组文件夹，将模组文件夹拖入，启动游戏即可  
完成后主菜单左下角版本后面会显示已加载的模组数量

### 开发
需要有一定的 GDScript 编程基础

#### 模组结构
```
user://mods/模组名称/
├── manifest.json
├── main.gd
├── ...
```

`manifest.json` 是模组信息清单，包含模组的名称、版本、目标版本、入口脚本，例如:  
```json
{
    "name": "test mod",
    "version": "1.0.0",
    "target": "*",
    "entry": "main.gd"
}
```

`main.gd` 是模组的主脚本，用于加载模组的场景、UI、数据等，例如:  
```gdscript
class_name TestMod extends BaseMod

func _on_mod_load(mod_info: ModInfo):
	print("test mod loaded, godot " + mod_info.godot_version + ", running at " + mod_info.dir)

func _on_scene_changed(node: Node):
	print("test mod scene changed to " + node.name)
```

`ModInfo` 的结构:  
```gdscript
class_name ModInfo extends Object

var name: String = ""
var version: String = ""
var target: String = ""
var entry: String = ""
var godot_version: String = ""
var game_version: String = ""
var protocol: int = 0
var dir: String = ""
```

`BaseMod` 的结构:  
```gdscript
class_name BaseMod extends Node

func _on_mod_load(mod_info: ModInfo) -> void:
	pass
```

其他功能请参照 Godot 官方文档

### 模组最终用户许可(MOD EULA)
- 不得使用模组破坏多人游戏玩法和体验
- 不得使用模组进行商业或任何盈利用途
- 模组不需要开源

## 许可证
- 自由软件许可证: [GNU General Public License v3 (GPL v3)](LICENSE)
- 游戏本体: MIKE KLUBNIKA All Rights Reserved.