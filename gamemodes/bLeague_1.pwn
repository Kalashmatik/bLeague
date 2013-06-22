/*



TODO:



*/



#file               "bLeague.amx"



#include 					<a_samp>
#include                    <a_http>
#include 					<audio>
#include                    <cmd>
#include 					<dns>
#include 					<mail>
#include                    <map>
#include                    <multimap>
#include 					<mysql>
#include                    <npc>
#include 					<regex>
#include 					<sha512>
#include 					<socket>
#include 					<streamer>
#include 					<timerfix>
#include                    <vector>





#pragma amxram      		16777216
#pragma compress    		1
#pragma dynamic     		65535
#pragma tabsize     		4
#pragma pack        		0
//#pragma semicolon   		0
#pragma ctrlchar    		'\\'





//#define DEBUG

#define mail_host           "127.0.0.1"
#define mail_user           "root"
#define mail_password       "root1"
#define mail_from           "bjiadokc@bleague.com"

#define mysql_host  		"127.0.0.1"
#define mysql_user  		"root"
#define mysql_password      "root1"
#define mysql_db            "server"
#define mysql_charset       "utf8"



#define GivePVarInt(%0,%1,%2) \
	SetPVarInt(%0,%1,GetPVarInt(%0,%1)+%2)
	
#define IsPlayerConnected(%0) \
	(cvector_find(playersVector, %0) != -1)
	
#define IsVehicleSpawned(%0) \
	(cvector_find(vehiclesVector, %0) != -1)
	
#define foreach_p(%0) \
	for(new %0, %0_m = cvector_size(playersVector), %0_i; %0_i != %0_m; %0 = cvector_get(playersVector, %0_i++))
	
#define foreach_n(%0) \
	for(new %0, %0_m = cvector_size(npcVector), %0_i; %0_i != %0_m; %0 = cvector_get(npcVector, %0_i++))
	
#define foreach_o(%0) \
	for(new %0, %0_m = cvector_size(objectsVector), %0_i; %0_i != %0_m; %0 = cvector_get(objectsVector, %0_i++))
	
#define foreach_v(%0) \
	for(new %0, %0_m = cvector_size(vehiclesVector), %0_i; %0_i != %0_m; %0 = cvector_get(vehiclesVector, %0_i++))





new serverMap;
new mysqlHandle;
new socketHandle;
new mailRegex;
new nameRegex;
new passwordRegex;
new audioMap;
new vehiclesMap;
new vehiclesVector;
new playersVector;
new objectsVector;
new pickupsVector;
new checkpointsVector;
new raceCheckpointsVector;
new mapIconsVector;
new textLabelsVector;
new npcMap;
new npcVector;





enum (+= 1)
{
	SERVER_INFO_HOSTNAME = 0,
	SERVER_INFO_IP,
	SERVER_INFO_PORT,
	SERVER_INFO_MAX_PLAYERS
}



enum (+= 1)
{
	VEHICLE_INFO_MODEL = 0,
	VEHICLE_INFO_X,
	VEHICLE_INFO_Y,
	VEHICLE_INFO_Z,
	VEHICLE_INFO_ANGLE,
	VEHICLE_INFO_COLOR1,
	VEHICLE_INFO_COLOR2,
	VEHICLE_INFO_PAINTJOB
}





main()
{

}



public OnGameModeInit()
{
	#if defined DEBUG
	printf("[%i]OnGameModeInit()", funcidx("OnGameModeInit"));
	#endif
	
	DisableNameTagLOS();
	SetNameTagDrawDistance(10.0);
	LimitPlayerMarkerRadius(10.0);
	
	serverMap = cmap();
	
	new buffer[256];
	
	GetServerVarAsString("hostname", buffer, sizeof buffer);
	cmap_insert_key_int_arr(serverMap, SERVER_INFO_HOSTNAME, buffer);
	
	GetServerVarAsString("bind", buffer, sizeof buffer);
	
	if(strlen(buffer))
	{
		cmap_insert_key_int_arr(serverMap, SERVER_INFO_IP, buffer);
	}
	else
	{
	    HTTP(SERVER_INFO_IP, HTTP_GET, "localhost/engine/ip.php", "", "OnServerIPGet");
	}
	
	cmap_insert_key_int(serverMap, SERVER_INFO_PORT, GetServerVarAsInt("port"));
	cmap_insert_key_int(serverMap, SERVER_INFO_MAX_PLAYERS, GetServerVarAsInt("maxplayers"));
	
	mailRegex = regex_build("^([a-zA-Z0-9_\\-\\.]+)@([a-zA-Z0-9_\\-\\.]+)\\.([a-zA-Z]{2,5})$");
	nameRegex = regex_build("^[A-z0-9@=_\\[\\]\\.\\(\\)\\$]{3,24}$");
	passwordRegex = regex_build("[ ?-??-?a-zA-Z0-9_,!\\.\\?\\-\\+\\(\\)]+");
	
	if(!regex_match_exid(mail_from, mailRegex))
	{
	    printf("Mail: \"From\" address (%s) is invalid", mail_from);
	}
	
	cmap_get_key_int_arr(serverMap, SERVER_INFO_HOSTNAME, buffer);
	mail_init(mail_host, mail_user, mail_password, mail_from, buffer);
	
	#if defined DEBUG
	mysql_log(LOG_DEBUG);
	#else
	mysql_log(LOG_ERROR | LOG_WARNING);
	#endif
	
	mysqlHandle = mysql_connect(mysql_host, mysql_user, mysql_db, mysql_password);
	
	mysql_set_charset(#mysql_charset "_general_ci");
	mysql_function_query(mysqlHandle, "SET NAMES " #mysql_charset, false, "OnMySQLCharsetChange", "s", mysql_charset);
	
	cmap_get_key_int_arr(serverMap, SERVER_INFO_IP, buffer);
	socketHandle = _:socket_create(UDP);
	
	if(strlen(buffer))
	{
		socket_bind(Socket:socketHandle, buffer);
	}
	
	socket_listen(Socket:socketHandle, cmap_get_key_int(serverMap, SERVER_INFO_PORT) + 1);
	
	Audio_SetPack("bLeague", true, false);
	audioMap = cmmap();
	
	playersVector = cvector();
	
	npcVector = cvector();
	npcMap = cmmap();
	
	FCNPC_SetUpdateRate(250);
	
	new npcNames[19][24] =
	{
	    {"Destroyer"},
	    {"Boom_Baby"},
	    {"GrenadeMaster"},
	    {"pr0_sn1per"},
	    {"theCheater"},
	    {"KeepYourFaceClean"},
	    {"SDraw"},
	    {"FrostLee"},
	    {"Tracker1"},
	    {"OFFREAL"},
	    {"Vinny"},
	    {"azen"},
	    {"Roman1us"},
	    {"Breed"},
	    {"SlootLite"},
	    {"Lamp0"},
	    {"Demetr1us"},
	    {"Blazer321"},
	    {"Maverick"}
	};
	
	for(new i, npc; i != 19; i++)
	{
		npc = FCNPC_Create("1");
		SetPlayerName(npc, npcNames[i]);
		FCNPC_Spawn(npc, 0, -5.0 + random(10), -7.0 + random(10), 3.2);
		
		cmmap_insert_key_int_arr(npcMap, npc, npcNames[i]);
	}
	
	mysql_function_query(mysqlHandle, "SELECT * FROM `vehicles` WHERE 1", true, "OnVehiclesLoad", "i", vehiclesMap);
	mysql_function_query(mysqlHandle, "SELECT * FROM `objects` WHERE 1", true, "OnObjectsLoad", "");
	mysql_function_query(mysqlHandle, "SELECT * FROM `pickups` WHERE 1", true, "OnPickupsLoad", "");
	mysql_function_query(mysqlHandle, "SELECT * FROM `checkpoints` WHERE 1", true, "OnCheckpointsLoad", "i", false);
	mysql_function_query(mysqlHandle, "SELECT * FROM `race_checkpoints` WHERE 1", true, "OnCheckpointsLoad", "i", true);
	mysql_function_query(mysqlHandle, "SELECT * FROM `map_icons` WHERE 1", true, "OnMapIconsLoad", "");
	mysql_function_query(mysqlHandle, "SELECT * FROM `3d_text_labels` WHERE 1", true, "On3DTextsLoad", "");
	
 	return 1;
}



public OnVehiclesLoad();
public OnVehiclesLoad()
{
	#if defined DEBUG
	printf("[%i]OnVehiclesLoad()", funcidx("OnVehiclesLoad"));
	#endif
	
	vehiclesMap = cmmap();
	vehiclesVector = cvector();
	
	new rows;
	new fields;
	
	cache_get_data(rows, fields, mysqlHandle);
	
	printf("Vehicles for load: %i", rows);
	
	while(rows--)
	{
	    new model = cache_get_field_content_int(rows, "modelid", mysqlHandle);
	    new Float:x = cache_get_field_content_float(rows, "x", mysqlHandle);
	    new Float:y = cache_get_field_content_float(rows, "y", mysqlHandle);
	    new Float:z = cache_get_field_content_float(rows, "z", mysqlHandle);
	    new Float:angle = cache_get_field_content_float(rows, "angle", mysqlHandle);
	    new color1 = cache_get_field_content_int(rows, "color1", mysqlHandle);
	    new color2 = cache_get_field_content_int(rows, "color2", mysqlHandle);
	    new respawn_delay = cache_get_field_content_int(rows, "respawn_delay", mysqlHandle);
	    
		new id = CreateVehicle(model, x, y, z, angle, color1, color2, respawn_delay);
		
		if(id == INVALID_VEHICLE_ID)
		{
		    printf("Error while creating vehicle on row %i", rows);
		    
		    break;
		}
		
		cmmap_insert_key_int(vehiclesMap, id, model);
		cmmap_insert_key_int_float(vehiclesMap, id, x);
		cmmap_insert_key_int_float(vehiclesMap, id, y);
		cmmap_insert_key_int_float(vehiclesMap, id, z);
		cmmap_insert_key_int_float(vehiclesMap, id, angle);
		cmmap_insert_key_int(vehiclesMap, id, color1);
		cmmap_insert_key_int(vehiclesMap, id, color2);
		cmmap_insert_key_int(vehiclesMap, id, 0);
		
		cvector_push_back(vehiclesVector, id);
	}

	printf("Vehicles created: %i", cvector_size(vehiclesVector));
	
	return 1;
}

		

public OnObjectsLoad();
public OnObjectsLoad()
{
	#if defined DEBUG
	printf("[%i]OnObjectsLoad()", funcidx("OnObjectsLoad"));
	#endif
	
    objectsVector = cvector();
    
	new rows;
	new fields;
	
	cache_get_data(rows, fields, mysqlHandle);
	
	printf("Objects for load: %i", rows);
	
	while(rows--)
	{
		new id = CreateDynamicObject( \
			cache_get_field_content_int(rows, "modelid", mysqlHandle), \
			cache_get_field_content_float(rows, "x", mysqlHandle), \
			cache_get_field_content_float(rows, "y", mysqlHandle), \
			cache_get_field_content_float(rows, "z", mysqlHandle), \
			cache_get_field_content_float(rows, "rx", mysqlHandle), \
			cache_get_field_content_float(rows, "ry", mysqlHandle), \
			cache_get_field_content_float(rows, "rz", mysqlHandle));
			
		if(!IsValidDynamicObject(id))
		{
		    printf("Error while creating object on row %i", rows);
		    
		    break;
		}
		
		cvector_push_back(objectsVector, id);
	}
	
	printf("Objects created: %i", CountDynamicObjects());
	
	return 1;
}



public OnPickupsLoad();
public OnPickupsLoad()
{
	#if defined DEBUG
	printf("[%i]OnPickupsLoad()", funcidx("OnPickupsLoad"));
	#endif
	
	pickupsVector = cvector();
	
	new rows;
	new fields;
	
	cache_get_data(rows, fields, mysqlHandle);
	
	printf("Pickups for load: %i", rows);
	
	while(rows--)
	{
	    new id = CreateDynamicPickup( \
	        cache_get_field_content_int(rows, "modelid", mysqlHandle), \
	        cache_get_field_content_int(rows, "type", mysqlHandle), \
	        cache_get_field_content_float(rows, "x", mysqlHandle), \
	        cache_get_field_content_float(rows, "y", mysqlHandle), \
	        cache_get_field_content_float(rows, "z", mysqlHandle));
	        
		if(!IsValidDynamicPickup(id))
		{
		    printf("Error while creating pickup on row %i", rows);
		    
		    break;
		}
		
		cvector_push_back(pickupsVector, id);
	}
	
	printf("Pickups created: %i", CountDynamicPickups());
	
	return 1;
}



public OnCheckpointsLoad(bool:racecp);
public OnCheckpointsLoad(bool:racecp)
{
	#if defined DEBUG
	printf("[%i]OnCheckpointsLoad(racecp: %s)", funcidx("OnCheckpointsLoad"), racecp ? ("true") : ("false"));
	#endif
	
	new rows;
	new fields;
	
	cache_get_data(rows, fields, mysqlHandle);
	
	if(!racecp)
	{
	    checkpointsVector = cvector();
	    
	    printf("Checkpoints for load: %i", rows);
	    
	    while(rows--)
	    {
	        new id = CreateDynamicCP( \
	            cache_get_field_content_float(rows, "x", mysqlHandle), \
	            cache_get_field_content_float(rows, "y", mysqlHandle), \
	            cache_get_field_content_float(rows, "z", mysqlHandle), \
	            cache_get_field_content_float(rows, "size", mysqlHandle));
	            
			if(!IsValidDynamicCP(id))
			{
			    printf("Error while creating checkpoint on row %i", rows);
			    
			    break;
			}
			
			cvector_push_back(checkpointsVector, id);
		}
		
		printf("Checkpoints created: %i", CountDynamicCPs());
	}
	else
	{
	    raceCheckpointsVector = cvector();
	    
	    printf("Race checkpoints for load: %i", rows);
	    
	    while(rows--)
	    {
	        new id = CreateDynamicRaceCP( \
	            cache_get_field_content_int(rows, "type", mysqlHandle), \
	            cache_get_field_content_float(rows, "x", mysqlHandle), \
	            cache_get_field_content_float(rows, "y", mysqlHandle), \
	            cache_get_field_content_float(rows, "z", mysqlHandle), \
	            cache_get_field_content_float(rows, "nx", mysqlHandle), \
	            cache_get_field_content_float(rows, "ny", mysqlHandle), \
	            cache_get_field_content_float(rows, "nz", mysqlHandle), \
	            cache_get_field_content_float(rows, "size", mysqlHandle));
	            
			if(!IsValidDynamicRaceCP(id))
			{
			    printf("Error while creating race checkpoint on row %i", rows);
			    
			    break;
			}
			
			cvector_push_back(raceCheckpointsVector, id);
		}
		
		printf("Race checkpoints created: %i", CountDynamicRaceCPs());
	}
	
	return 1;
}



public OnMapIconsLoad();
public OnMapIconsLoad()
{
	#if defined DEBUG
	printf("[%i]OnMapIconsLoad()", funcidx("OnMapIconsLoad"));
	#endif
	
	mapIconsVector = cvector();
	
	new rows;
	new fields;
	
	cache_get_data(rows, fields, mysqlHandle);
	
	printf("Map icons for load: %i", rows);
	
	while(rows--)
	{
	    new id = CreateDynamicMapIcon( \
	        cache_get_field_content_float(rows, "x", mysqlHandle), \
	        cache_get_field_content_float(rows, "y", mysqlHandle), \
	        cache_get_field_content_float(rows, "z", mysqlHandle), \
	        cache_get_field_content_int(rows, "type", mysqlHandle), \
	        cache_get_field_content_int(rows, "color", mysqlHandle));
	        
		if(!IsValidDynamicMapIcon(id))
		{
		    printf("Error while creating map icon on row %i", rows);
		    
		    break;
		}
		
		cvector_push_back(mapIconsVector, id);
	}
	
	printf("Map icons created: %i", CountDynamicMapIcons());
	
	return 1;
}



public On3DTextsLoad();
public On3DTextsLoad()
{
	#if defined DEBUG
	printf("[%i]On3DTextsLoad()", funcidx("On3DTextsLoad"));
	#endif
	
	textLabelsVector = cvector();
	
	new rows;
	new fields;
	
	cache_get_data(rows, fields, mysqlHandle);
	
	printf("3D text labels for load: %i", rows);
	
	while(rows--)
	{
	    new text[2048];
	    
	    cache_get_field_content(rows, "text", text, mysqlHandle);
	    
	    new id = _:CreateDynamic3DTextLabel(text, \
	        cache_get_field_content_int(rows, "color", mysqlHandle), \
	        cache_get_field_content_float(rows, "x", mysqlHandle), \
	        cache_get_field_content_float(rows, "y", mysqlHandle), \
	        cache_get_field_content_float(rows, "z", mysqlHandle), \
	        cache_get_field_content_float(rows, "drawdistance", mysqlHandle));
	        
		if(!IsValidDynamic3DTextLabel(Text3D:id))
		{
		    printf("Error wjile creating 3D text label on row %i", rows);
		    
		    break;
		}
		
		cvector_push_back(textLabelsVector, id);
	}
	
	printf("3D text labels created: %i", CountDynamic3DTextLabels());
	
	return 1;
}



public OnServerIPGet(index, response_code, ip[]);
public OnServerIPGet(index, response_code, ip[])
{
	if((200 <= response_code <= 299))
	{
	    cmap_insert_key_int_arr(serverMap, index, ip);
	    
	    socket_bind(Socket:socketHandle, ip);
	}
	
	return 1;
}



public OnGameModeExit()
{
	#if defined DEBUG
	printf("[%i]OnGameModeExit()", funcidx("OnGameModeExit"));
	#endif
	
	foreach_n(i)
	{
	    FCNPC_Destroy(i);
	    KillTimer(GetPVarInt(i, "npc_timer"));
	}
	
	cvector_clear(npcVector);
	cmmap_clear(npcMap);
	
	foreach_p(i)
	{
	    Kick(i);
	}

	cvector_clear(playersVector);

	foreach_v(i)
	{
	    DestroyVehicle(i);
	}

	cvector_clear(vehiclesVector);
	cmmap_clear(vehiclesMap);

	DestroyAllDynamicObjects();
	cvector_clear(objectsVector);
	
	DestroyAllDynamicPickups();
	cvector_clear(pickupsVector);
	
	DestroyAllDynamicCPs();
	cvector_clear(checkpointsVector);
	
	DestroyAllDynamicRaceCPs();
	cvector_clear(raceCheckpointsVector);
	
	DestroyAllDynamicMapIcons();
	cvector_clear(mapIconsVector);
	
	DestroyAllDynamic3DTextLabels();
	cvector_clear(textLabelsVector);

	cmmap_clear(audioMap);

	regex_delete_all();

	socket_stop_listen(Socket:socketHandle);
	socket_destroy(Socket:socketHandle);

	mysql_close(mysqlHandle);

	return 1;
}



public OnRconLoginAttempt(ip[], password[], success)
{
	#if defined DEBUG
	printf("[%i]OnRconLoginAttempt(ip: '%s', password: '%s', success: %i)", funcidx("OnRconLoginAttempt"), ip, password, success);
	#endif
	
	return 1;
}



public OnRconCommand(cmd[])
{
	#if defined DEBUG
	printf("[%i]OnRconCommand(cmd: '%s')", funcidx("OnRconCommand"), cmd);
	#endif
	
	return 1;
}



public OnPlayerConnect(playerid)
{
	#if defined DEBUG
	printf("[%i]OnPlayerConnect(playerid: %i)", funcidx("OnPlayerConnect"), playerid);
	#endif
	
	if(IsPlayerNPC(playerid))
	{
	    printf("NPC %i connected", playerid);
	    
	    new npcIP[16];
	    
	    GetPlayerIp(playerid, npcIP, sizeof npcIP);
	    
	    if(strcmp(npcIP, "127.0.0.1", false) && strcmp(npcIP, "255.255.255.255", false))
	    {
	        printf("Invalid NPC connected from %s", npcIP);
	        Kick(playerid);
	        
	        return 1;
		}
		
	    cvector_push_back(npcVector, playerid);
	    
	    return 1;
	}
	
	cvector_push_back(playersVector, playerid);
	
	PlayAudioStreamForPlayer(playerid, "http://127.0.0.1/intro.mp3");
	SetPVarInt(playerid, "audio_play", true);
	
	new playerVersion[12];
	new playerIP[16];
	new playerName[25];
	
	GetPlayerVersion(playerid, playerVersion, sizeof playerVersion);
	GetPlayerIp(playerid, playerIP, sizeof playerIP);
	GetPlayerName(playerid, playerName, sizeof playerName);
	
	if(!regex_match_exid(playerName, nameRegex))
	{
	    printf("Invalid player name (%s) from playerid %i", playerName, playerid);
	}
	
	rdns(playerIP, playerid);
	
	SetPVarString(playerid, "samp_version", playerVersion);
	SetPVarString(playerid, "ip", playerIP);
	SetPVarString(playerid, "name", playerName);
	
 	return 1;
}



public Audio_OnClientConnect(playerid)
{
	#if defined DEBUG
	printf("[%i]Audio_OnClientConnect(playerid: %i)", funcidx("Audio_OnClientConnect"), playerid);
	#endif
	
	if(!IsPlayerConnected(playerid))
	{
	    printf("Audio: Client %i connected before in-game join, or player already disconnected", playerid);
	}
	
    Audio_TransferPack(playerid);
    
	return 1;
}



public Audio_OnClientConnected(playerid);
public Audio_OnClientConnected(playerid)
{
	#if defined DEBUG
	printf("[%i]Audio_OnClientConnected(playerid: %i)", funcidx("Audio_OnClientConnected"), playerid);
	#endif
	
	StopAudioStreamForPlayer(playerid);
	
	new audioid = Audio_CreateSequence();
	
	Audio_AddToSequence(audioid, 2);
	Audio_AddToSequence(audioid, 3);
	Audio_AddToSequence(audioid, 1);
	Audio_AddToSequence(audioid, 2);
	Audio_AddToSequence(audioid, 3);
	
	SetPVarInt(playerid, "audio_queue", audioid);
	Audio_PlaySequence(playerid, audioid);
	
	return 1;
}



public FCNPC_OnCreate(npcid)
{
	#if defined DEBUG
	printf("[%i]FCNPC_OnCreate(npcid: %i)", funcidx("FCNPC_OnCreate"), npcid);
	#endif

	return 1;
}



public OnPlayerDisconnect(playerid, reason)
{
	#if defined DEBUG
	printf("[%i]OnPlayerDisconnect(playerid: %i, reason: %i)", funcidx("OnPlayerDisconnect"), playerid, reason);
	#endif
	
    cvector_remove(playersVector, cvector_find(playersVector, playerid));
	
	return 1;
}



public Audio_OnClientDisconnect(playerid)
{
	#if defined DEBUG
	printf("[%i]Audio_OnClientDisconnect(playerid: %i)", funcidx("Audio_OnClientDisconnect"), playerid);
	#endif
	
	for(new i = cmmap_count_int(audioMap, playerid); i != 0; i--)
	{
		Audio_Stop(playerid, i);
	}
	
	Audio_DestroySequence(GetPVarInt(playerid, "audio_queue"));
	
	cmmap_remove_int(audioMap, playerid);
	DeletePVar(playerid, "audio_play");
	DeletePVar(playerid, "audio_track");
	DeletePVar(playerid, "audio_queue");
	
	if(IsPlayerConnected(playerid))
	{
	    printf("Audio: Client %i disconnected before in-game leave", playerid);
	}
	
	return 1;
}



public OnPlayerRequestClass(playerid, classid)
{
	#if defined DEBUG
	printf("[%i]OnPlayerRequestClass(playerid: %i, classid: %i)", funcidx("OnPlayerRequestClass"), playerid, classid);
	#endif
	
	return 1;
}



public OnPlayerRequestSpawn(playerid)
{
	#if defined DEBUG
	printf("[%i]OnPlayerRequestSpawn(playerid: %i)", funcidx("OnPlayerRequestSpawn"), playerid);
	#endif
	
	return 1;
}



public OnPlayerSpawn(playerid)
{
	#if defined DEBUG
	printf("[%i]OnPlayerSpawn(playerid: %i)", funcidx("OnPlayerSpawn"), playerid);
	#endif
	
	SetPlayerPos(playerid, 7.0, 4.0, 3.2);
	
	return 1;
}



public FCNPC_OnSpawn(npcid)
{
	#if defined DEBUG
	printf("[%i]FCNPC_OnSpawn(npcid: %i)", funcidx("FCNPC_OnSpawn"), npcid);
	#endif
	
	FCNPC_SetWeapon(npcid, 31);
	FCNPC_SetAmmo(npcid, 10000);
	
	SetPVarInt(npcid, "npc_timer", SetTimerEx("OnNPCUpdate", 250, true, "i", npcid));
	
	return 1;
}



public FCNPC_OnRespawn(npcid)
{
	#if defined DEBUG
	printf("[%i]FCNPC_OnRespawn(npcid: %i)", funcidx("FCNPC_OnRespawn"), npcid);
	#endif
	
	return 1;
}



public OnVehicleSpawn(vehicleid)
{
	#if defined DEBUG
	printf("[%i]OnVehicleSpawn(vehicleid: %i)", funcidx("OnVehicleSpawn"), vehicleid);
	#endif
	
	cvector_push_back(vehiclesVector, vehicleid);

	new Float:x;
	new Float:y;
	new Float:z;
	
	GetVehiclePos(vehicleid, x, y, z);
	
	cmmap_set_key_int_float(vehiclesMap, vehicleid, VEHICLE_INFO_X, x);
	cmmap_set_key_int_float(vehiclesMap, vehicleid, VEHICLE_INFO_Y, y);
	cmmap_set_key_int_float(vehiclesMap, vehicleid, VEHICLE_INFO_Z, z);
	
	GetVehicleZAngle(vehicleid, z);
	
	cmmap_set_key_int_float(vehiclesMap, vehicleid, VEHICLE_INFO_ANGLE, z);
	
	ChangeVehicleColor(vehicleid, cmmap_get_key_int(vehiclesMap, vehicleid, VEHICLE_INFO_COLOR1), cmmap_get_key_int(vehiclesMap, vehicleid, VEHICLE_INFO_COLOR2));
	ChangeVehiclePaintjob(vehicleid, cmmap_get_key_int(vehiclesMap, vehicleid, VEHICLE_INFO_PAINTJOB));
	
	return 1;
}



public OnPlayerDeath(playerid, killerid, reason)
{
	#if defined DEBUG
	printf("[%i]OnPlayerDeath(playerid: %i, killerid: %i, reason: %i)", funcidx("OnPlayerDeath"), playerid, killerid, reason);
	#endif
	
	return 1;
}



public OnVehicleDeath(vehicleid, killerid)
{
	#if defined DEBUG
	printf("[%i]OnVehicleDeath(vehicleid: %i, killerid: %i)", funcidx("OnVehicleDeath"), vehicleid, killerid);
	#endif
	
	cvector_remove(vehiclesVector, cvector_find(vehiclesVector, vehicleid));
	
	SetVehicleToRespawn(vehicleid);
	
	return 1;
}



public FCNPC_OnDeath(npcid, killerid, weaponid)
{
	#if defined DEBUG
	printf("[%i]FCNPC_OnDeath(npcid: %i, killerid: %i, weaponid: %i)", funcidx("FCNPC_OnDeath"), npcid, killerid, weaponid);
	#endif
	
	KillTimer(GetPVarInt(npcid, "npc_timer"));
	
	return 1;
}



public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger)
{
	#if defined DEBUG
	printf("[%i]OnPlayerEnterVehicle(playerid: %i, vehicleid: %i, ispassenger: %i)", funcidx("OnPlayerEnterVehicle"), playerid, vehicleid, ispassenger);
	#endif
	
	return 1;
}



public FCNPC_OnVehicleEntryComplete(npcid, vehicleid, seat)
{
	#if defined DEBUG
	printf("[%i]FCNPC_OnVehicleEntryComplete(npcid: %i, vehicleid: %i, seat: %i)", funcidx("FCNPC_OnVehicleEntryComplete"), npcid, vehicleid, seat);
	#endif
	
	return 1;
}



public OnPlayerExitVehicle(playerid, vehicleid)
{
	#if defined DEBUG
	printf("[%i]OnPlayerExitVehicle(playerid: %i, vehicleid: %i)", funcidx("OnPlayerExitVehicle"), playerid, vehicleid);
	#endif
	
	return 1;
}



public FCNPC_OnVehicleExitComplete(npcid)
{
	#if defined DEBUG
	printf("[%i]FCNPC_OnVehicleExitComplete(npcid: %i)", funcidx("FCNPC_OnVehicleExitComplete"), npcid);
	#endif
	
	return 1;
}



public OnPlayerStateChange(playerid, newstate, oldstate)
{
	#if defined DEBUG
	printf("[%i]OnPlayerStateChange(playerid: %i, newstate: %i, oldstate: %i)", funcidx("OnPlayerStateChange"), playerid, newstate, oldstate);
	#endif
	
	switch(newstate)
	{
	    case PLAYER_STATE_DRIVER:
	    {
	        if(GetPVarInt(playerid, "audio_play"))
	        {
	            Audio_StopRadio(playerid);
			}
		}
		
		case PLAYER_STATE_PASSENGER:
		{
		    if(GetPVarInt(playerid, "audio_play"))
		    {
		        Audio_StopRadio(playerid);
			}
		}
	}
	
	return 1;
}



public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	#if defined DEBUG
	//printf("[%i]OnPlayerKeyStateChange(%i, %i, %i)", funcidx("OnPlayerKeyStateChange"), playerid, newkeys, oldkeys);
	#endif
	
	return 1;
}



public OnPlayerInteriorChange(playerid, newinteriorid, oldinteriorid)
{
	#if defined DEBUG
	printf("[%i]OnPlayerInteriorChange(playerid: %i, newinteriorid: %i, oldinteriorid: %i)", funcidx("OnPlayerInteriorChange"), playerid, newinteriorid, oldinteriorid);
	#endif
	
	return 1;
}



public OnPlayerText(playerid, text[])
{
	#if defined DEBUG
	printf("[%i]OnPlayerText(playerid: %i, text: '%s')", funcidx("OnPlayerText"), playerid, text);
	#endif
	
	return 1;
}



public OnPlayerCommandText(playerid, cmdtext[])
{
	#if defined DEBUG
	printf("[%i]OnPlayerCommandText(playerid: %i, cmdtext: '%s')", funcidx("OnPlayerCommandText"), playerid, cmdtext);
	#endif
	
	return 1;
}



public OnPlayerSelectedMenuRow(playerid, row)
{
	#if defined DEBUG
	printf("[%i]OnPlayerSelectedMenuRow(playerid: %i, row: %i)", funcidx("OnPlayerSelectedMenuRow"), playerid, row);
	#endif
	
	return 1;
}



public OnPlayerExitedMenu(playerid)
{
	#if defined DEBUG
	printf("[%i]OnPlayerExitedMenu(playerid: %i)", funcidx("OnPlayerExitedMenu"), playerid);
	#endif
	
	return 1;
}



public OnPlayerClickMap(playerid, Float:fX, Float:fY, Float:fZ)
{
	#if defined DEBUG
	printf("[%i]OnPlayerClickMap(playerid: %i, x: %f, y: %f, z: %f)", funcidx("OnPlayerClickMap"), playerid, fX, fY, fZ);
	#endif
	
	return 1;
}



public OnPlayerClickPlayer(playerid, clickedplayerid, source)
{
	#if defined DEBUG
	printf("[%i]OnPlayerClickPlayer(playerid: %i, clickedplayerid: %i, source: %i)", funcidx("OnPlayerClickPlayer"), playerid, clickedplayerid, source);
	#endif
	
	return 1;
}



public OnPlayerClickTextDraw(playerid, Text:clickedid)
{
	#if defined DEBUG
	printf("[%i]OnPlayerClickTextDraw(playerid: %i, textid: %i)", funcidx("OnPlayerClickTextDraw"), playerid, _:clickedid);
	#endif
	
	return 1;
}



public OnPlayerClickPlayerTextDraw(playerid, PlayerText:playertextid)
{
	#if defined DEBUG
	printf("[%i]OnPlayerClickPlayerTextDraw(playerid: %i, playertextid: %i)", funcidx("OnPlayerClickPlayerTextDraw"), playerid, _:playertextid);
	#endif
	
	return 1;
}



public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	#if defined DEBUG
	printf("[%i]OnDialogResponse(playerid: %i, dialogid: %i, response: %i, listitem: %i, inputtext: '%s')", funcidx("OnDialogResponse"), playerid, dialogid, response, listitem, inputtext);
	#endif
	
	return 1;
}



public OnPlayerStreamIn(playerid, forplayerid)
{
	#if defined DEBUG
	printf("[%i]OnPlayerStreamIn(playerid: %i, forplayerid: %i)", funcidx("OnPlayerStreamIn"), playerid, forplayerid);
	#endif
	
	return 1;
}



public OnPlayerStreamOut(playerid, forplayerid)
{
	#if defined DEBUG
	printf("[%i]OnPlayerStreamOut(playerid: %i, forplayerid: %i)", funcidx("OnPlayerStreamOut"), playerid, forplayerid);
	#endif

	return 1;
}



public OnVehicleStreamIn(vehicleid, forplayerid)
{
	#if defined DEBUG
	printf("[%i]OnVehicleStreamIn(vehicleid: %i, forplayerid: %i)", funcidx("OnVehicleStreamIn"), vehicleid, forplayerid);
	#endif
	
	return 1;
}



public OnVehicleStreamOut(vehicleid, forplayerid)
{
	#if defined DEBUG
	printf("[%i]OnVehicleStreamOut(vehicleid: %i, forplayerid: %i)", funcidx("OnVehicleStreamOut"), vehicleid, forplayerid);
	#endif

	return 1;
}



public OnPlayerUpdate(playerid)
{
	#if defined DEBUG
	//printf("[%i]OnPlayerUpdate(%i)", funcidx("OnPlayerUpdate"), playerid);
	#endif
	
	new Float:x;
	new Float:y;
	new Float:z;
	
	GetPlayerPos(playerid, x, y, z);
	
	foreach_n(i)
	{
		if(!FCNPC_IsMoving(i))
		{
	    	FCNPC_AimAt(i, x, y, z - floatdiv(GetPlayerDistanceFromPoint(i, x, y, z), 15.0), true);
		}
	}
	
	return 1;
}



public OnNPCUpdate(npcid);
public OnNPCUpdate(npcid)
{
	switch(random(10))
	{
		case 0:
  		{
  		    if(FCNPC_IsMoving(npcid))
		    {
		        FCNPC_Stop(npcid);
			}
			
  			new Float:x;
	    	new Float:y;
	    	new Float:z;

    		FCNPC_GetPosition(npcid, x, y, z);
    		x += random(10) - random(10);
    		y += random(10) - random(10);
	    		
            FCNPC_GoTo(npcid, x, y, z, MOVE_TYPE_WALK, 0.0, true);
		}
			
		case 6:
		{
		    if(FCNPC_IsMoving(npcid))
		    {
		        FCNPC_Stop(npcid);
			}
			
		    FCNPC_SetSpecialAction(npcid, SPECIAL_ACTION_DUCK);
		}
		
		case 1..5:
		{
		    if(FCNPC_IsMoving(npcid))
		    {
		        FCNPC_Stop(npcid);
			}
		}
		
		case 7..9:
		{
		    if(FCNPC_GetSpecialAction(npcid) == SPECIAL_ACTION_DUCK)
		    {
		        FCNPC_SetSpecialAction(npcid, SPECIAL_ACTION_NONE);
			}
		}
	}
	
	return 1;
}



public OnUnoccupiedVehicleUpdate(vehicleid, playerid, passenger_seat)
{
	#if defined DEBUG
	//printf("[%i]OnUnoccupiedVehicleUpdate(%i, %i, %i)", funcidx("OnUnoccupiedVehicleUpdate"), vehicleid, playerid, passenger_seat);
	#endif
	
	return 1;
}



public FCNPC_OnReachDestination(npcid)
{
	#if defined DEBUG
	printf("[%i]FCNPC_OnReachDestination(npcid: %i)", funcidx("FCNPC_OnReachDestination"), npcid);
	#endif
	
	return 1;
}



public OnPlayerTakeDamage(playerid, issuerid, Float:amount, weaponid)
{
	#if defined DEBUG
	printf("[%i]OnPlayerTakeDamage(playerid: %i, issuerid: %i, amount: %f, weaponid: %i)", funcidx("OnPlayerTakeDamage"), playerid, issuerid, amount, weaponid);
	#endif
	
	return 1;
}



public FCNPC_OnTakeDamage(npcid, damagerid, weaponid)
{
	#if defined DEBUG
	printf("[%i]FCNPC_OnTakeDamage(npcid: %i, damagerid: %i, weaponid: %i)", funcidx("FCNPC_OnTakeDamage"), npcid, damagerid, weaponid);
	#endif
	
	return 1;
}



public OnPlayerGiveDamage(playerid, damagedid, Float:amount, weaponid)
{
	#if defined DEBUG
	printf("[%i]OnPlayerGiveDamage(playerid: %i, damagedid: %i, amount: %f, weaponid: %i)", funcidx("OnPlayerGiveDamage"), playerid, damagedid, amount, weaponid);
	#endif
	
	return 1;
}



public OnVehicleDamageStatusUpdate(vehicleid, playerid)
{
	#if defined DEBUG
	printf("[%i]OnVehicleDamageStatusUpdate(vehicleid: %i, playerid: %i)", funcidx("OnVehicleDamageStatusUpdate"), vehicleid, playerid);
	#endif

	return 1;
}



public Audio_OnTransferFile(playerid, file[], current, total, result)
{
	#if defined DEBUG
	printf("[%i]Audio_OnTransferFile(playerid: %i, file: '%s', current: %i, total: %i, result: %i)", funcidx("Audio_OnTransferFile"), playerid, file, current, total, result);
	#endif
	
	switch(result)
	{
	    case 3: return CallLocalFunction("Audio_OnTransferFileError", "isii", playerid, file, current, total);
	}
	
	if(current == total)
	{
	    CallLocalFunction("Audio_OnClientConnected", "i", playerid);
	}
	        
	return 1;
}



public Audio_OnPlay(playerid, handleid)
{
	#if defined DEBUG
	printf("[%i]Audio_OnPlay(playerid: %i, handleid: %i)", funcidx("Audio_OnPlay"), playerid, handleid);
	#endif
	
	cmap_insert_key_int(audioMap, playerid, handleid);
	SetPVarInt(playerid, "audio_play", true);
	
	return 1;
}



public Audio_OnStop(playerid, handleid)
{
	#if defined DEBUG
	printf("[%i]Audio_OnStop(playerid: %i, handleid: %i)", funcidx("Audio_OnStop"), playerid, handleid);
	#endif
	
	cmmap_remove_int(audioMap, playerid, handleid);
	SetPVarInt(playerid, "audio_play", false);
	
	return 1;
}



public Audio_OnTrackChange(playerid, handleid, track[])
{
	#if defined DEBUG
	printf("[%i]Audio_OnTrackChange(playerid: %i, handleid: %i, track: '%s')", funcidx("Audio_OnTrackChange"), playerid, handleid, track);
	#endif
	
	return 1;
}



public Audio_OnRadioStationChange(playerid, station)
{
	#if defined DEBUG
	printf("[%i]Audio_OnRadioStationChange(playerid: %i, station: %i)", funcidx("Audio_OnRadioStationChange"), playerid, station);
	#endif
	
	return 1;
}



public Audio_OnGetPosition(playerid, handleid, seconds)
{
	#if defined DEBUG
	printf("[%i]Audio_OnGetPosition(playerid: %i, handleid: %i, seconds: %i)", funcidx("Audio_OnGetPosition"), playerid, handleid, seconds);
	#endif
	
	return 1;
}



public OnVehicleMod(playerid, vehicleid, componentid)
{
	#if defined DEBUG
	printf("[%i]OnVehicleMod(playerid: %i, vehicleid: %i, componentid: %i)", funcidx("OnVehicleMod"), playerid, vehicleid, componentid);
	#endif
	
	return 1;
}



public OnEnterExitModShop(playerid, enterexit, interiorid)
{
	#if defined DEBUG
	printf("[%i]OnEnterExitModShop(playerid: %i, enterexit: %i, interiorid: %i)", funcidx("OnEnterExitModShop"), playerid, enterexit, interiorid);
	#endif
	
	return 1;
}



public OnVehiclePaintjob(playerid, vehicleid, paintjobid)
{
	#if defined DEBUG
	printf("[%i]OnVehiclePaintjob(playerid: %i, vehicleid: %i, paintjobid: %i)", funcidx("OnVehiclePaintjob"), playerid, vehicleid, paintjobid);
	#endif
	
	return 1;
}



public OnVehicleRespray(playerid, vehicleid, color1, color2)
{
	#if defined DEBUG
	printf("[%i]OnVehicleRespray(playerid: %i, vehicleid: %i, color1: %i, color2: %i)", funcidx("OnVehicleRespray"), playerid, vehicleid, color1, color2);
	#endif
	
	return 1;
}



public OnDynamicObjectMoved(objectid)
{
	#if defined DEBUG
	printf("[%i]OnDynamicObjectMoved(objectid: %i)", funcidx("OnDynamicObjectMoved"), objectid);
	#endif
	
	return 1;
}



public OnPlayerEditDynamicObject(playerid, objectid, response, Float:x, Float:y, Float:z, Float:rx, Float:ry, Float:rz)
{
	#if defined DEBUG
	printf("[%i]OnPlayerEditDynamicObject(playerid: %i, objectid: %i, response: %i, x: %f, y: %f, z: %f, rx: %f, ry: %f, rz: %f)", funcidx("OnPlayerEditDynamicObject"), playerid, objectid, response, x, y, z, rx, ry, rz);
	#endif
	
	return 1;
}



public OnPlayerEditAttachedObject(playerid, response, index, modelid, boneid, Float:fOffsetX, Float:fOffsetY, Float:fOffsetZ, Float:fRotX, Float:fRotY, Float:fRotZ, Float:fScaleX, Float:fScaleY, Float:fScaleZ)
{
	#if defined DEBUG
	printf("[%i]OnPlayerEditAttachedObject(playerid: %i, response: %i, index: %i, modelid: %i, boneid: %i, offsetX: %f, offsetY: %f, offsetZ: %f, rotX: %f, rotY: %f, rotZ: %f, scaleX: %f, scaleY: %f, scaleZ: %f)", funcidx("OnPlayerEditAttachedObject"), playerid, response, index, modelid, boneid, fOffsetX, fOffsetY, fOffsetZ, fRotX, fRotY, fRotZ, fScaleX, fScaleY, fScaleZ);
	#endif
	
	return 1;
}



public OnPlayerSelectDynamicObject(playerid, objectid, modelid, Float:x, Float:y, Float:z)
{
	#if defined DEBUG
	printf("[%i]OnPlayerSelectDynamicObject(playerid: %i, objectid: %i, modelid: %i, x: %f, y: %f, z: %f)", funcidx("OnPlayerSelectDynamicObject"), playerid, objectid, modelid, x, y, z);
	#endif
	
	return 1;
}



public OnPlayerPickUpDynamicPickup(playerid, pickupid)
{
	#if defined DEBUG
	printf("[%i]OnPlayerPickUpDynamicPickup(playerid: %i, pickupid: %i)", funcidx("OnPlayerPickUpDynamicPickup"), playerid, pickupid);
	#endif
	
	return 1;
}



public OnPlayerEnterDynamicCP(playerid, checkpointid)
{
	#if defined DEBUG
	printf("[%i]OnPlayerEnterDynamicCP(playerid: %i, checkpointid: %i)", funcidx("OnPlayerEnterDynamicCP"), playerid, checkpointid);
	#endif
	
	return 1;
}



public OnPlayerLeaveDynamicCP(playerid, checkpointid)
{
	#if defined DEBUG
	printf("[%i]OnPlayerLeaveDynamicCP(playerid: %i, checkpointid: %i)", funcidx("OnPlayerLeaveDynamicCP"), playerid, checkpointid);
	#endif
	
	return 1;
}



public OnPlayerEnterDynamicRaceCP(playerid, checkpointid)
{
	#if defined DEBUG
	printf("[%i]OnPlayerEnterDynamicRaceCP(playerid: %i, checkpointid: %i)", funcidx("OnPlayerEnterDynamicRaceCP"), playerid, checkpointid);
	#endif
	
	return 1;
}



public OnPlayerLeaveDynamicRaceCP(playerid, checkpointid)
{
	#if defined DEBUG
	printf("[%i]OnPlayerLeaveDynamicRaceCP(playerid: %i, checkpointid: %i)", funcidx("OnPlayerLeaveDynamicRaceCP"), playerid, checkpointid);
	#endif
	
	return 1;
}



public OnPlayerEnterDynamicArea(playerid, areaid)
{
	#if defined DEBUG
	printf("[%i]OnPlayerEnterDynamicArea(playerid: %i, areaid: %i)", funcidx("OnPlayerEnterDynamicArea"), playerid, areaid);
	#endif
	
	return 1;
}



public OnPlayerLeaveDynamicArea(playerid, areaid)
{
	#if defined DEBUG
	printf("[%i]OnPlayerLeaveDynamicArea(playerid: %i, areaid: %i)", funcidx("OnPlayerLeaveDynamicArea"), playerid, areaid);
	#endif
	
	return 1;
}



public OnDNS(host[], ip[], extra)
{
	#if defined DEBUG
	printf("[%i]OnDNS(host: '%s', ip: '%s', extra: %i)", funcidx("OnDNS"), host, ip, extra);
	#endif
	
	return 1;
}



public OnReverseDNS(ip[], host[], extra)
{
	#if defined DEBUG
	printf("[%i]OnReverseDNS(ip: '%s', host: '%s', extra: %i)", funcidx("OnReverseDNS"), ip, host, extra);
	#endif
	
	if(!strcmp(ip, host, false))
	{
	    printf("Error while retrieving host for IP %s", ip);
	    
	    return 1;
	}
	
	if(IsPlayerConnected(extra))
	{
	    SetPVarString(extra, "dns", host);
	}
	
	return 1;
}



public onUDPReceiveData(Socket:id, data[], data_len, remote_client_ip[], remote_client_port)
{
	#if defined DEBUG
	printf("[%i]onUDPReceiveData(socketid: %i, data: '%s', length: %i, remote_ip: '%s', remote_port: %i)", funcidx("onUDPReceiveData"), _:id, data, data_len, remote_client_ip, remote_client_port);
	#endif
	
	return 1;
}



public OnMailSendSuccess(index, to[], subject[], message[], type)
{
	#if defined DEBUG
	printf("[%i]OnMailSendSuccess(index: %i, to: '%s', subject: '%s', message: '%s', type: %i)", funcidx("OnMailSendSuccess"), index, to, subject, message, type);
	#endif
	
	return 1;
}



public OnMailSendError(index, to[], subject[], message[], type, error[], error_code)
{
	#if defined DEBUG
	printf("[%i]OnMailSendError(index: %i, to: '%s', subject: '%s', message: '%s', type: %i, error: '%s', error_code: %i)", funcidx("OnMailSendError"), index, to, subject, message, type, error, error_code);
	#endif
	
	return 1;
}



public OnMySQLCharsetChange(charset[]);
public OnMySQLCharsetChange(charset[])
{
	#if defined DEBUG
	printf("[%i]OnMySQLCharsetChange(charset: '%s')", funcidx("OnMySQLCharsetChange"), charset);
	#endif
	
	mysql_function_query(mysqlHandle, "SET SESSION character_set_server = utf8", false, "", "");
	
	return 1;
}



public Audio_OnTransferFileError(playerid, file[], current, total);
public Audio_OnTransferFileError(playerid, file[], current, total)
{
	#if defined DEBUG
	printf("[%i]Audio_OnTransferFileError(playerid: %i, file: '%s', current: %i, total: %i)", funcidx("Audio_OnTransferFileError"), playerid, file, current, total);
	#endif
	
	return 1;
}



public OnQueryError(errorid, error[], callback[], query[], connectionHandle)
{
	#if defined DEBUG
	printf("[%i]OnQueryError(errorid: %i, error: '%s', callback: '%s', query: '%s', handle: %i)", funcidx("OnQueryError"), errorid, error, callback, query, connectionHandle);
	#endif
	
	return 1;
}



public OnRuntimeError(error_code, &bool:suppress);
public OnRuntimeError(error_code, &bool:suppress)
{
	#if defined DEBUG
	printf("[%i]OnRuntimeError(error_code: %i, suppress: %s)", funcidx("OnRuntimeError"), error_code, suppress ? ("true") : ("false"));
	#endif
	
	suppress = false;

	return 1;
}



public OnPlayerCommandReceived(playerid, command[], params[], params_length)
{
	#if defined DEBUG
	printf("[%i]OnPlayerCommandReceived(playerid: %i, command: '%s', params: '%s', params_length: %i)", funcidx("OnPlayerCommandReceived"), playerid, command, params, params_length);
	#endif
	
	return 1;
}



public OnPlayerCommandPerformed(playerid, command[], params[], params_length, return_code)
{
	#if defined DEBUG
	printf("[%i]OnPlayerCommandPerformed(playerid: %i, command: '%s', params: '%s', params_length: %i, return_code: %i)", funcidx("OnPlayerCommandPerformed"), playerid, command, params, params_length, return_code);
	#endif
	
	return 1;
}



TCMD:mypos(playerid, params[], params_length)
{
	new Float:x;
	new Float:y;
	new Float:z;
	
	new string[64];
	
	GetPlayerPos(playerid, x, y, z);
	
	format(string, sizeof string, "x: %f     y: %f     z: %f", x, y, z);
	SendClientMessage(playerid, -1, string);
	
	return 1;
}
