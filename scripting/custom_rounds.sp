#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma newdecls required
#pragma semicolon 1

#define PREFIX " \x04"... PREFIX_NO_COLOR ..."\x01"
#define PREFIX_NO_COLOR "[Custom Rounds]"

enum struct CustomRoundConVar
{
	ConVar cvar;
	char value[64];
}

enum struct CustomRound
{
	char name[64];
	
	ArrayList convars;
	ArrayList items;
	
	void Init()
	{
		this.convars = new ArrayList(sizeof(CustomRoundConVar));
		this.items = new ArrayList(ByteCountToCells(64));
	}
	
	void Close()
	{
		delete this.convars;
		delete this.items;
	}
}
ArrayList g_CustomRounds;

// Backup of the ConVars that got changed.
ArrayList g_ConVarsBackup;

// Wheter or not the current map should have custom rounds.
bool g_CustomRoundsEnabled;

public Plugin myinfo = 
{
	name = "Custom Rounds", 
	author = "Natanel 'LuqS'", 
	description = "", 
	version = "1.0.0", 
	url = "https://steamcommunity.com/id/luqsgood || Discord: LuqS#6505"
};

public void OnPluginStart()
{
	if (GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("This plugin is for CSGO only.");
	}
	
	// Global variables.
	g_CustomRounds = new ArrayList(sizeof(CustomRound));
	g_ConVarsBackup = new ArrayList(sizeof(CustomRoundConVar));
	
	// Events
	HookEvent("round_freeze_end", Event_OnFreezeEnd, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_OnRoundEnd);
	
	// Commands
	RegAdminCmd("sm_toggle_custom_rounds", Command_ToggleCustomRounds, ADMFLAG_ROOT);
}

public void OnPluginEnd()
{
	// Restore convars
	SetCustomRoundConvars(g_ConVarsBackup);
}

// Command to toggle costom rounds.
public Action Command_ToggleCustomRounds(int client, int argc)
{
	PrintToChatAll("%s 'Custom Rounds' are now %s\x01!", PREFIX, (g_CustomRoundsEnabled = !g_CustomRoundsEnabled) ? "\x04Enabled" : "\x02Disabled");

	return Plugin_Handled;
}

// Parse config.
public void OnMapStart()
{
	// Delete old custom rounds.
	CustomRound current_custom_round_data;
	for (int current_custom_round; current_custom_round < g_CustomRounds.Length; current_custom_round++)
	{
		g_CustomRounds.GetArray(current_custom_round, current_custom_round_data);
		current_custom_round_data.Close();
	}
	
	g_CustomRounds.Clear();
	
	// Find the Config.
	char file_path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, file_path, sizeof(file_path), "configs/custom_rounds.cfg");
	
	// Create new kv variable to itirate in
	KeyValues kv = new KeyValues("CustomRounds");
	
	// Import the file to the new kv variable
	if (!kv.ImportFromFile(file_path))
	{
		SetFailState("Couldn't load plugin config.");
	}
	
	// Sub string to match.
	char map_substr[64];
	kv.GetString("map_substr", map_substr, sizeof(map_substr));
	
	// Get map name.
	char map_name[PLATFORM_MAX_PATH];
	GetCurrentMap(map_name, sizeof(map_name));
	
	// Check if the sub str is in the map name.
	g_CustomRoundsEnabled = StrContains(map_name, map_substr) != -1;
	
	if (!kv.GotoFirstSubKey())
	{
		SetFailState("There are no custom rounds in the config.");
	}
	
	// Itirate through
	do
	{
		CustomRound new_custom_round;
		
		new_custom_round.Init();
		
		// Get round name
		kv.GetSectionName(new_custom_round.name, sizeof(CustomRound::name));
		
		if (kv.JumpToKey("convars"))
		{
			if (kv.GotoFirstSubKey(false))
			{
				char convar_name[64];
			
				do
				{
					CustomRoundConVar new_custom_convar;
					
					// Get convar name
					kv.GetSectionName(convar_name, sizeof(convar_name));
					
					// If the convar can't be found, just skip it
					if (!(new_custom_convar.cvar = FindConVar(convar_name)))
					{
						continue;
					}
					
					// Get convar name
					kv.GetString(NULL_STRING, new_custom_convar.value, sizeof(CustomRoundConVar::value));
					
					// Add to custom round convars
					new_custom_round.convars.PushArray(new_custom_convar);
					
				} while (kv.GotoNextKey(false));
				
				kv.GoBack();
			}
			
			kv.GoBack();
		}
		
		if (kv.JumpToKey("items"))
		{
			if (kv.GotoFirstSubKey(false))
			{
				char item_name[64];
			
				do
				{
					kv.GetString(NULL_STRING, item_name, sizeof(item_name));
					new_custom_round.items.PushString(item_name);
					
				} while (kv.GotoNextKey(false));
			
				kv.GoBack();
			}
			
			kv.GoBack();
		}
		
		g_CustomRounds.PushArray(new_custom_round);
		
	} while (kv.GotoNextKey());
	
	delete kv;
}

// Start random custom round, set all convars and give all wepoans.
public void Event_OnFreezeEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_CustomRoundsEnabled)
	{
		return;
	}
	
	CustomRound random_custom_round;
	g_CustomRounds.GetArray(GetRandomInt(0, g_CustomRounds.Length - 1), random_custom_round);
	
	SetCustomRoundConvars(random_custom_round.convars, true);
	
	GiveCustomRoundItemsToAllPlayers(random_custom_round.items);
	
	DataPack dp;
	CreateDataTimer(0.3, Timer_ShowCustomRoundMessage, dp);
	dp.WriteString(random_custom_round.name);
}

Action Timer_ShowCustomRoundMessage(Handle timer, DataPack dp)
{
	dp.Reset();
	
	char custom_round_name[64];
	dp.ReadString(custom_round_name, sizeof(custom_round_name));
	
	ShowPanel2(4, "<font class='fontSize-l'><span color='#ff0000'>C</span><span color='#e90015'>u</span><span color='#d4002a'>s</span><span color='#bf003f'>t</span><span color='#aa0055'>o</span><span color='#94006a'>m</span> <span color='#6a0094'>R</span><span color='#5500aa'>o</span><span color='#3f00bf'>u</span><span color='#2a00d4'>n</span><span color='#1500e9'>d</span>\n%s</font>", custom_round_name);
}

// Restore all convars to how they were before the custom round.
public void Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	// Restore convars
	SetCustomRoundConvars(g_ConVarsBackup);
	
	// Clear old convars backup.
	g_ConVarsBackup.Clear();
}

void SetCustomRoundConvars(ArrayList custom_round_convars, bool backup = false)
{
	CustomRoundConVar current_custom_convar_data;
	for (int current_custom_convar; current_custom_convar < custom_round_convars.Length; current_custom_convar++)
	{
		custom_round_convars.GetArray(current_custom_convar, current_custom_convar_data);
		
		if (backup)
		{
			CustomRoundConVar backup_custom_convar;
			
			// Save convar
			backup_custom_convar.cvar = current_custom_convar_data.cvar;
			
			// Save original value
			current_custom_convar_data.cvar.GetString(backup_custom_convar.value, sizeof(CustomRoundConVar::value));
			
			// Push to backup arraylist.
			g_ConVarsBackup.PushArray(backup_custom_convar);
		}
		
		current_custom_convar_data.cvar.SetString(current_custom_convar_data.value);
	}
}

void GiveCustomRoundItemsToAllPlayers(ArrayList custom_round_items)
{
	char current_item_name[64];
	for (int current_item; current_item < custom_round_items.Length; current_item++)
	{
		custom_round_items.GetString(current_item, current_item_name, sizeof(current_item_name));
		
		for(int current_client = 1; current_client <= MaxClients; current_client++)
		{
			if (IsClientInGame(current_client) && IsPlayerAlive(current_client))
			{
				GivePlayerItem(current_client, current_item_name);
			}
		}
	}
}


void ShowPanel2(int duration, const char[] format, any...)
{
	static char formatted_message[1024];
	VFormat(formatted_message, sizeof(formatted_message), format, 3);
	
	Event show_survival_respawn_status = CreateEvent("show_survival_respawn_status");
	
	show_survival_respawn_status.SetString("loc_token", formatted_message);
	show_survival_respawn_status.SetInt("duration", duration);
	show_survival_respawn_status.SetInt("userid", -1);
	
	show_survival_respawn_status.Fire();
}