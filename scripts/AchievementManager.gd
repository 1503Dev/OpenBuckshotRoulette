class_name Achievement extends Node

func UnlockAchievement(apiname : String):
	if GlobalVariables.using_steam:
		#Steam.setAchievement(apiname)
		#Steam.storeStats()
		pass

func ClearAchievement(apiname : String):
	if GlobalVariables.using_steam:
		#Steam.clearAchievement(apiname)
		#Steam.storeStats()
		pass
