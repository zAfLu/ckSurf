public void CreateZoneEntity(int zoneIndex)
{
	float fMiddle[3], fMins[3], fMaxs[3];
	char sZoneName[64];
	
	if (g_mapZones[zoneIndex][PointA][0] == -1.0 && g_mapZones[zoneIndex][PointA][1] == -1.0 && g_mapZones[zoneIndex][PointA][2] == -1.0)
	{
		return;
	}
	
	Array_Copy(g_mapZones[zoneIndex][PointA], fMins, 3);
	Array_Copy(g_mapZones[zoneIndex][PointB], fMaxs, 3);
	
	Format(sZoneName, sizeof(sZoneName), "%s", g_mapZones[zoneIndex][zoneName]);
	
	int iEnt = CreateEntityByName("trigger_multiple");
	
	if (iEnt > 0 && IsValidEntity(iEnt)) {
		SetEntityModel(iEnt, ZONE_MODEL);
		// Spawnflags:	1 - only a player can trigger this by touch, makes it so a NPC cannot fire a trigger_multiple
		// 2 - Won't fire unless triggering ent's view angles are within 45 degrees of trigger's angles (in addition to any other conditions), so if you want the player to only be able to fire the entity at a 90 degree angle you would do ",angles,0 90 0," into your spawnstring.
		// 4 - Won't fire unless player is in it and pressing use button (in addition to any other conditions), you must make a bounding box,(max\mins) for this to work.
		// 8 - Won't fire unless player/NPC is in it and pressing fire button, you must make a bounding box,(max\mins) for this to work.
		// 16 - only non-player NPCs can trigger this by touch
		// 128 - Start off, has to be activated by a target_activate to be touchable/usable
		// 256 - multiple players can trigger the entity at the same time
		DispatchKeyValue(iEnt, "spawnflags", "257");
		DispatchKeyValue(iEnt, "StartDisabled", "0");
		
		Format(sZoneName, sizeof(sZoneName), "sm_ckZone %i", zoneIndex);
		DispatchKeyValue(iEnt, "targetname", sZoneName);
		DispatchKeyValue(iEnt, "wait", "0");
		
		if (DispatchSpawn(iEnt))
		{
			ActivateEntity(iEnt);
			
			GetMiddleOfABox(fMins, fMaxs, fMiddle);
			
			TeleportEntity(iEnt, fMiddle, NULL_VECTOR, NULL_VECTOR);
			
			// Have the mins always be negative
			for(int i = 0; i < 3; i++){
				fMins[i] = fMins[i] - fMiddle[i];
				if(fMins[i] > 0.0)
					fMins[i] *= -1.0;
			}
			
			// And the maxs always be positive
			for(int i = 0; i < 3; i++){
				fMaxs[i] = fMaxs[i] - fMiddle[i];
				if(fMaxs[i] < 0.0)
					fMaxs[i] *= -1.0;
			}
			
			SetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
			SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);
			SetEntProp(iEnt, Prop_Send, "m_nSolidType", 2);
			
			int iEffects = GetEntProp(iEnt, Prop_Send, "m_fEffects");
			iEffects |= 0x020;
			SetEntProp(iEnt, Prop_Send, "m_fEffects", iEffects);
			
			
			SDKHook(iEnt, SDKHook_StartTouch, StartTouchTrigger);
			SDKHook(iEnt, SDKHook_EndTouch, EndTouchTrigger);
		}
		else
		{
			
			LogError("Not able to dispatchspawn for Entity %i in SpawnTrigger", iEnt);
		}
	}
}
// Types: Start(1), End(2), Stage(3), Checkpoint(4), Speed(5), TeleToStart(6), Validator(7), Chekcer(8), Stop(0)

public Action StartTouchTrigger(int caller, int activator)
{
	// Ignore dead players
	if (!IsValidClient(activator))
		return Plugin_Handled;
	
	char sTargetName[256];
	int action[3];
	GetEntPropString(caller, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
	ReplaceString(sTargetName, sizeof(sTargetName), "sm_ckZone ", "");
	
	int id = StringToInt(sTargetName);
	
	action[0] = g_mapZones[id][zoneType];
	action[1] = g_mapZones[id][zoneTypeId];
	action[2] = g_mapZones[id][zoneGroup];
	
	if (action[2] == g_iClientInZone[activator][2]) // Is touching zone in right zonegroup
	{
		// Set client location 
		g_iClientInZone[activator][0] = action[0];
		g_iClientInZone[activator][1] = action[1];
		g_iClientInZone[activator][2] = action[2];
		g_iClientInZone[activator][3] = id;
		StartTouch(activator, action);
	}
	else
	{
		if (action[0] == 1 || action[0] == 5) // Ignore other than start and misc zones in other zonegroups
		{
			// Set client location 
			g_iClientInZone[activator][0] = action[0];
			g_iClientInZone[activator][1] = action[1];
			g_iClientInZone[activator][2] = action[2];
			g_iClientInZone[activator][3] = id;
			StartTouch(activator, action);
		}
		else
			if (action[0] == 6 || action[0] == 7 || action[0] == 8 || action[0] == 0) // Allow MISC zones regardless of zonegroup
				StartTouch(activator, action);
	}
	
	return Plugin_Handled;
}

public Action EndTouchTrigger(int caller, int activator)
{
	// Ignore dead players
	if (!IsValidClient(activator))
		return Plugin_Handled;
	
	// Ignore if teleporting out of the zone
	if (g_bIgnoreZone[activator])
	{
		g_bIgnoreZone[activator] = false;
		return Plugin_Handled;
	}
	
	char sTargetName[256];
	int action[3];
	GetEntPropString(caller, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
	ReplaceString(sTargetName, sizeof(sTargetName), "sm_ckZone ", "");
	
	int id = StringToInt(sTargetName);
	
	action[0] = g_mapZones[id][zoneType];
	action[1] = g_mapZones[id][zoneTypeId];
	action[2] = g_mapZones[id][zoneGroup];

	if (action[2] != g_iClientInZone[activator][2] || action[0] == 6 || action[0] == 8 || action[0] != g_iClientInZone[activator][0]) // Ignore end touches in other zonegroups, zones that teleports away or multiple zones on top of each other 
		return Plugin_Handled;

	// End touch
	EndTouch(activator, action);
	
	return Plugin_Handled;
}

public void StartTouch(int client, int action[3])
{
	if (IsValidClient(client))
	{
		// Types: Start(1), End(2), Stage(3), Checkpoint(4), Speed(5), TeleToStart(6), Validator(7), Chekcer(8), Stop(0)
		
		if (action[0] == 0) // Stop Zone
		{
			Client_Stop(client, 1);
			lastCheckpoint[g_iClientInZone[client][2]][client] = 999;
		}
		else if (action[0] == 1 || action[0] == 5) // Start Zone or Speed Start
		{
			if (g_Stage[g_iClientInZone[client][2]][client] == 1 && g_bPracticeMode[client]) // If practice mode is on
				Command_goToPlayerCheckpoint(client, 1);
			else
			{
				g_Stage[g_iClientInZone[client][2]][client] = 1;
				
				Client_Stop(client, 1);
				// Resetting last checkpoint
				lastCheckpoint[g_iClientInZone[client][2]][client] = 1;
			}
		}
		else if (action[0] == 2) // End Zone
		{
			if (g_iClientInZone[client][2] == action[2]) //  Cant end bonus timer in this zone && in the having the same timer on
				CL_OnEndTimerPress(client);
			else
			{
				Client_Stop(client, 1);
			}
			if (g_bPracticeMode[client]) // Go back to normal mode if checkpoint mode is on
			{
				Command_normalMode(client, 1);
				clearPlayerCheckPoints(client);
			}
			// Resetting checkpoints
			lastCheckpoint[g_iClientInZone[client][2]][client] = 999;
		}
		else if (action[0] == 3) // Stage Zone
		{
			if (g_bPracticeMode[client]) // If practice mode is on
			{
				if (action[1] > lastCheckpoint[g_iClientInZone[client][2]][client] && g_iClientInZone[client][2] == action[2] || lastCheckpoint[g_iClientInZone[client][2]][client] == 999)
				{
					Command_normalMode(client, 1); // Temp fix. Need to track stages checkpoints were made in.
				}
				else
					Command_goToPlayerCheckpoint(client, 1);
			}
			else
			{  // Setting valid to false, in case of checkers
				g_bValidRun[client] = false;
				
				// Announcing checkpoint
				if (action[1] != lastCheckpoint[g_iClientInZone[client][2]][client] && g_iClientInZone[client][2] == action[2])
				{
					g_Stage[g_iClientInZone[client][2]][client] = (action[1] + 2);
					Checkpoint(client, action[1], g_iClientInZone[client][2]);
					lastCheckpoint[g_iClientInZone[client][2]][client] = action[1];
				}
			}
		}
		else if (action[0] == 4) // Checkpoint Zone
		{
			if (action[1] != lastCheckpoint[g_iClientInZone[client][2]][client] && g_iClientInZone[client][2] == action[2])
			{
				// Announcing checkpoint in linear maps
				Checkpoint(client, action[1], g_iClientInZone[client][2]);
				lastCheckpoint[g_iClientInZone[client][2]][client] = action[1];
			}
		}
		else if (action[0] == 6) // TeleToStart Zone
		{
			teleportClient(client, g_iClientInZone[client][2], 1, true);
		}
		else if (action[0] == 7) // Validator Zone
		{
			g_bValidRun[client] = true;
		}
		else if (action[0] == 8) // Checker Zone
		{
			if (!g_bValidRun[client])
				Command_Teleport(client, 1);
		}
	}
}

public void EndTouch(int client, int action[3])
{
	if (IsValidClient(client))
	{
		// Types: Start(1), End(2), Stage(3), Checkpoint(4), Speed(5), TeleToStart(6), Validator(7), Chekcer(8), Stop(0)
		if (action[0] == 1 || action[0] == 5)
		{
			if (g_bPracticeMode[client] && !g_bTimeractivated[client]) // If on practice mode, but timer isn't on - start timer
			{
				CL_OnStartTimerPress(client);
			}
			else
			{
				if (!g_bPracticeMode[client])
				{	
					g_Stage[g_iClientInZone[client][2]][client] = 1;
					lastCheckpoint[g_iClientInZone[client][2]][client] = 999;
					
					// NoClip check
					if (g_bNoClip[client] || (!g_bNoClip[client] && (GetGameTime() - g_fLastTimeNoClipUsed[client]) < 3.0))
					{
						PrintToChat(client, "[%cCK%c] You are noclipping or have noclipped recently, timer disabled.", MOSSGREEN, WHITE);
						ClientCommand(client, "play buttons\\button10.wav");
					}
					else
						CL_OnStartTimerPress(client);

					g_bValidRun[client] = false;
				}
			}
		}
		
		// Set client location
		g_iClientInZone[client][0] = -1;
		g_iClientInZone[client][1] = -1;
		g_iClientInZone[client][2] = action[2];
		g_iClientInZone[client][3] = -1;
	}
}

public void InitZoneVariables()
{
	g_mapZonesCount = 0;
	for (int i = 0; i < MAXZONES; i++) 
	{
		g_mapZones[i][zoneId] = -1;
		g_mapZones[i][PointA] = -1.0;
		g_mapZones[i][PointB] = -1.0;
		g_mapZones[i][zoneId] = -1;
		g_mapZones[i][zoneType] = -1;
		g_mapZones[i][zoneTypeId] = -1;
		g_mapZones[i][zoneGroup] = -1;
		g_mapZones[i][zoneName] = 0;
		g_mapZones[i][Vis] = 0;
		g_mapZones[i][Team] = 0;
	}
}

public void getZoneTeamColor(int team, int color[4])
{
	switch (team)
	{
		case 1:
		{
			color = beamColorM;
		}
		case 2:
		{
			color = beamColorT;
		}
		case 3:
		{
			color = beamColorCT;
		}
		default:
		{
			color = beamColorN;
		}
	}
}

public void DrawBeamBox(int client)
{
	int zColor[4];
	getZoneTeamColor(g_CurrentZoneTeam[client], zColor);
	TE_SendBeamBoxToClient(client, g_Positions[client][1], g_Positions[client][0], g_BeamSprite, g_HaloSprite, 0, 30, 1.0, 5.0, 5.0, 2, 1.0, zColor, 0, 1);
	CreateTimer(1.0, BeamBox, client, TIMER_REPEAT);
}

public Action BeamBox(Handle timer, any client)
{
	if (IsClientInGame(client))
	{
		if (g_Editing[client] == 2)
		{
			int zColor[4];
			getZoneTeamColor(g_CurrentZoneTeam[client], zColor);
			TE_SendBeamBoxToClient(client, g_Positions[client][1], g_Positions[client][0], g_BeamSprite, g_HaloSprite, 0, 30, 1.0, 5.0, 5.0, 2, 1.0, zColor, 0, 1);
			return Plugin_Continue;
		}
	}
	return Plugin_Stop;
}

public Action BeamBoxAll(Handle timer, any data)
{
	int zColor[4], tzColor[4];
	bool draw;
	
	if (GetConVarInt(g_hZoneDisplayType) < 1)
		return Plugin_Handled;
	
	for (int i = 0; i < g_mapZonesCount; ++i)
	{
		draw = false;
		// Types: Start(1), End(2), Stage(3), Checkpoint(4), Speed(5), TeleToStart(6), Validator(7), Chekcer(8), Stop(0)
		if (0 < g_mapZones[i][Vis] < 4)
		{
			draw = true;
		}
		else
		{
			if (GetConVarInt(g_hZonesToDisplay) == 1 && ((0 < g_mapZones[i][zoneType] < 3) || g_mapZones[i][zoneType] == 5))
			{
				draw = true;
			}
			else
			{
				if (GetConVarInt(g_hZonesToDisplay) == 2 && ((0 < g_mapZones[i][zoneType] < 4) || g_mapZones[i][zoneType] == 5))
				{
					draw = true;
				}
				else
				{
					if (GetConVarInt(g_hZonesToDisplay) == 3)
					{
						draw = true;
					}
				}
			}
		}
		
		if (draw)
		{
			getZoneDisplayColor(g_mapZones[i][zoneType], zColor, g_mapZones[i][zoneGroup]);
			getZoneTeamColor(g_mapZones[i][Team], tzColor);
			for (int p = 1; p <= MaxClients; p++)
			{
				if (IsValidClient(p))
				{
					if ( g_mapZones[i][Vis] == 2 ||  g_mapZones[i][Vis] == 3)
					{
						if (GetClientTeam(p) ==  g_mapZones[i][Vis] && g_ClientSelectedZone[p] != i)
						{
							float buffer_a[3], buffer_b[3];
							for (int x = 0; x < 3; x++)
							{
								buffer_a[x] = g_mapZones[i][PointA][x];
								buffer_b[x] = g_mapZones[i][PointB][x];
							}
							TE_SendBeamBoxToClient(p, buffer_a, buffer_b, g_BeamSprite, g_HaloSprite, 0, 30, GetConVarFloat(g_hChecker), 5.0, 5.0, 2, 1.0, tzColor, 0, 0, i);
						}
					}
					else
					{
						if (g_ClientSelectedZone[p] != i)
						{
							float buffer_a[3], buffer_b[3];
							for (int x = 0; x < 3; x++)
							{
								buffer_a[x] = g_mapZones[i][PointA][x];
								buffer_b[x] = g_mapZones[i][PointB][x];
							}
							TE_SendBeamBoxToClient(p, buffer_a, buffer_b, g_BeamSprite, g_HaloSprite, 0, 30, GetConVarFloat(g_hChecker), 5.0, 5.0, 2, 1.0, zColor, 0, 0, i);
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public void getZoneDisplayColor(int type, int zColor[4], int zGrp)
{
	// Types: Start(1), End(2), Stage(3), Checkpoint(4), Speed(5), TeleToStart(6), Validator(7), Chekcer(8), Stop(0)
	switch (type)
	{
		case 1: {
			
			if (zGrp > 0)
				zColor = g_iZoneColors[3];
			else
				zColor = g_iZoneColors[1];
		}
		case 2: {
			if (zGrp > 0)
				zColor = g_iZoneColors[4];
			else
				zColor = g_iZoneColors[2];
		}
		case 3: {
			zColor = g_iZoneColors[5];
		}
		case 4: {
			zColor = g_iZoneColors[6];
		}
		case 5: {
			zColor = g_iZoneColors[7];
		}
		case 6: {
			zColor = g_iZoneColors[8];
		}
		case 7: {
			zColor = g_iZoneColors[9];
		}
		case 8: {
			zColor = g_iZoneColors[10];
		}
		case 0: {
			zColor = g_iZoneColors[0];
		}
		default:zColor = beamColorT;
	}
}

public void BeamBox_OnPlayerRunCmd(int client)
{
	if (g_Editing[client] == 1 || g_Editing[client] == 3 || g_Editing[client] == 10 || g_Editing[client] == 11)
	{
		float pos[3], ang[3];
		int zColor[4];
		getZoneTeamColor(g_CurrentZoneTeam[client], zColor);
		if (g_Editing[client] == 1)
		{
			GetClientEyePosition(client, pos);
			GetClientEyeAngles(client, ang);
			TR_TraceRayFilter(pos, ang, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
			TR_GetEndPosition(g_Positions[client][1]);
		}
		
		if (g_Editing[client] == 10 || g_Editing[client] == 11)
		{
			GetClientEyePosition(client, pos);
			GetClientEyeAngles(client, ang);
			TR_TraceRayFilter(pos, ang, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
			if (g_Editing[client] == 10)
			{
				TR_GetEndPosition(g_fBonusStartPos[client][1]);
				TE_SendBeamBoxToClient(client, g_fBonusStartPos[client][1], g_fBonusStartPos[client][0], g_BeamSprite, g_HaloSprite, 0, 30, 0.1, 5.0, 5.0, 2, 1.0, zColor, 0, 1);
			}
			else
			{
				TR_GetEndPosition(g_fBonusEndPos[client][1]);
				TE_SendBeamBoxToClient(client, g_fBonusEndPos[client][1], g_fBonusEndPos[client][0], g_BeamSprite, g_HaloSprite, 0, 30, 0.1, 5.0, 5.0, 2, 1.0, zColor, 0, 1);
			}
		}
		else
			TE_SendBeamBoxToClient(client, g_Positions[client][1], g_Positions[client][0], g_BeamSprite, g_HaloSprite, 0, 30, 0.1, 5.0, 5.0, 2, 1.0, zColor, 0, 1);
	}
}

stock void TE_SendBeamBoxToClient(int client, float uppercorner[3], float bottomcorner[3], int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, float Life, float Width, float EndWidth, int FadeLength, float Amplitude, const int Color[4], int Speed, int type, int zoneid = -1)
{
	//0 = Do not display zones, 1 = Display the lower edges of zones, 2 = Display whole zone
	if (!IsValidClient(client) || GetConVarInt(g_hZoneDisplayType) < 1)
		return;
	
	if (GetConVarInt(g_hZoneDisplayType) > 1 || type == 1) // All sides
	{
		float corners[8][3];
		if (zoneid == -1)
		{
			Array_Copy(uppercorner, corners[0], 3);
			Array_Copy(bottomcorner, corners[7], 3);

			// Count ponts from coordinates provided
			for(int i = 1; i < 7; i++)
			{
				for(int j = 0; j < 3; j++)
				{
					corners[i][j] = corners[((i >> (2-j)) & 1) * 7][j];
				}
			}
		}
		else
		{
			// Get values that are already counted
			for (int i = 0; i < 8; i++)
				for (int k = 0; k < 3; k++)
					corners[i][k] = g_fZoneCorners[zoneid][i][k];
		}

		// Send beams to client
		// https://forums.alliedmods.net/showpost.php?p=2006539&postcount=8
		for (int i = 0, i2 = 3; i2 >= 0; i+=i2--)
	    {
	        for(int j = 1; j <= 7; j += (j / 2) + 1)
	        {
	            if(j != 7-i)
	            {
					TE_SetupBeamPoints(corners[i], corners[j], ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
					TE_SendToClient(client);
				}
			}
		}
	}
	else
	{
		if (GetConVarInt(g_hZoneDisplayType) == 1 && zoneid != -1) // Only bottom corners
		{
			float corners[4][3], fTop[3];

			if (g_mapZones[zoneid][PointA][2] > g_mapZones[zoneid][PointB][2]) // Make sure bottom corner is always the lowest 
			{
				for(int i = 0; i < 3; i++)
				{
					corners[0][i] = g_mapZones[zoneid][PointB][i];
					fTop[i] = g_mapZones[zoneid][PointA][i];
				}
			}
			else
			{
				for(int i = 0; i < 3; i++)
				{
					corners[0][i] = g_mapZones[zoneid][PointA][i];
					fTop[i] = g_mapZones[zoneid][PointB][i];
				}		
			}

			bool foundOther = false;
			// Get other corners
			for (int i = 0, count = 0, k = 2; i < 8; i++)
			{
				if (g_fZoneCorners[zoneid][i][2] != fTop[2]) // Get the lowest corner
				{
					if (!foundOther && g_fZoneCorners[zoneid][i][0] == fTop[0] && g_fZoneCorners[zoneid][i][1] == fTop[1]) // Other corner
					{
						count++;
						for (int x = 0; x < 3; x++)
							corners[1][x] = g_fZoneCorners[zoneid][i][x];

						foundOther = true;
					}
					else
					{
						if (k < 4 && (g_fZoneCorners[zoneid][i][0] != corners[0][0] || g_fZoneCorners[zoneid][i][1] != corners[0][1])) // Other two corners
						{
							for (int x = 0; x < 3; x++)
								corners[k][x] = g_fZoneCorners[zoneid][i][x];

							count++;
							k++;
						}
					}
				}
				if (count == 3)
					break;
			}

			// lift a bit higher, so not under ground
			corners[0][2] += 5.0;
			corners[1][2] += 5.0;
			corners[2][2] += 5.0;
			corners[3][2] += 5.0;
			
			for (int i = 0; i < 2; i++) // Connect main corners to the other corners
			{
				TE_SetupBeamPoints(corners[i], corners[2], ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
				TE_SendToClient(client);
				TE_SetupBeamPoints(corners[i], corners[3], ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
				TE_SendToClient(client);
			}
		}
	}
}

//
// !zones menu starts here
//
public void ZoneMenu(int client)
{
	if (!IsValidClient(client))
		return;
	
	if (!(GetUserFlagBits(client) & g_ZoneMenuFlag) && !(GetUserFlagBits(client) & ADMFLAG_ROOT))
	{
		PrintToChat(client, "[%cCK%c] You don't have access to the zones menu.", MOSSGREEN, WHITE);
		return;
	}
	
	resetSelection(client);
	Menu ckZoneMenu = new Menu(Handle_ZoneMenu);
	ckZoneMenu.SetTitle("Zones");
	ckZoneMenu.AddItem("", "Create a Zone");
	ckZoneMenu.AddItem("", "Edit Zones");
	ckZoneMenu.AddItem("", "Save Zones");
	ckZoneMenu.AddItem("", "Edit Zone Settings");
	ckZoneMenu.AddItem("", "Reload Zones");
	ckZoneMenu.AddItem("", "Delete Zones");
	ckZoneMenu.ExitButton = true;
	ckZoneMenu.Display(client, MENU_TIME_FOREVER);
}



public int Handle_ZoneMenu(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0:
				{
					// Create a zone
					SelectZoneGroup(client);
				}
				case 1:
				{
					// Edit Zones
					EditZoneGroup(client);
				}
				case 2:
				{
					// Save Zones
					db_saveZones();
					resetSelection(client);
					ZoneMenu(client);
				}
				case 3:
				{
					// Edit Zone Settings 
					ZoneSettings(client);
				}
				case 4:
				{
					// Reload Zones
					db_selectMapZones();
					PrintToChat(client, "Zones are reloaded");
					resetSelection(client);
					ZoneMenu(client);
				}
				case 5:
				{
					// Delete zones
					ClearZonesMenu(client);
				}
			}
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}
public void EditZoneGroup(int client)
{
	Menu editZoneGroupMenu = new Menu(h_editZoneGroupMenu);
	editZoneGroupMenu.SetTitle("Which zones do you want to edit?");
	editZoneGroupMenu.AddItem("1", "Normal map zones");
	editZoneGroupMenu.AddItem("2", "Bonus zones");
	editZoneGroupMenu.AddItem("3", "Misc zones");
	editZoneGroupMenu.ExitButton = true;
	editZoneGroupMenu.Display(client, MENU_TIME_FOREVER);
}

public int h_editZoneGroupMenu(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0: // Normal map zones
				{
					g_CurrentSelectedZoneGroup[client] = 0;
					ListZones(client, true);
				}
				case 1: // Bonus Zones
				{
					ListBonusGroups(client);
				}
				case 2: // Misc zones
				{
					g_CurrentSelectedZoneGroup[client] = 0;
					ListZones(client, false);
				}
			}
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			ZoneMenu(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

public void ListBonusGroups(int client)
{
	Menu h_bonusGroupListing = new Menu(Handler_bonusGroupListing);
	h_bonusGroupListing.SetTitle("Available Bonuses");
	
	char listGroupName[256], ZoneId[64], Id[64];
	if (g_mapZoneGroupCount > 1)
	{  // Types: Start(1), End(2), Stage(3), Checkpoint(4), Speed(5), TeleToStart(6), Validator(7), Chekcer(8), Stop(0)
		for (int i = 1; i < g_mapZoneGroupCount; ++i)
		{
			Format(ZoneId, sizeof(ZoneId), "%s", g_szZoneGroupName[i]);
			IntToString(i, Id, sizeof(Id));
			Format(listGroupName, sizeof(listGroupName), ZoneId);
			h_bonusGroupListing.AddItem(Id, ZoneId);
		}
	}
	else
	{
		h_bonusGroupListing.AddItem("", "No Bonuses are available", ITEMDRAW_DISABLED);
	}
	h_bonusGroupListing.ExitButton = true;
	h_bonusGroupListing.Display(client, MENU_TIME_FOREVER);
}

public int Handler_bonusGroupListing(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char aID[64];
			GetMenuItem(tMenu, item, aID, sizeof(aID));
			g_CurrentSelectedZoneGroup[client] = StringToInt(aID);
			ListBonusSettings(client);
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			EditZoneGroup(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

public void ListBonusSettings(int client)
{
	Menu h_ListBonusSettings = new Menu(Handler_ListBonusSettings);
	h_ListBonusSettings.SetTitle("Settings for %s", g_szZoneGroupName[g_CurrentSelectedZoneGroup[client]]);
	
	h_ListBonusSettings.AddItem("1", "Create a new zone");
	h_ListBonusSettings.AddItem("2", "List Zones in this group");
	h_ListBonusSettings.AddItem("3", "Rename Bonus");
	h_ListBonusSettings.AddItem("4", "Delete this group");
	
	h_ListBonusSettings.ExitButton = true;
	h_ListBonusSettings.Display(client, MENU_TIME_FOREVER);
}

public int Handler_ListBonusSettings(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0:SelectBonusZoneType(client);
				case 1:listZonesInGroup(client);
				case 2:renameBonusGroup(client);
				case 3:checkForMissclick(client);
			}
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			ListBonusGroups(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

public void checkForMissclick(int client)
{
	Menu h_checkForMissclick = new Menu(Handle_checkForMissclick);
	h_checkForMissclick.SetTitle("Delete all zones in %s?", g_szZoneGroupName[g_CurrentSelectedZoneGroup[client]]);
	
	h_checkForMissclick.AddItem("1", "NO");
	h_checkForMissclick.AddItem("2", "NO");
	h_checkForMissclick.AddItem("3", "YES");
	h_checkForMissclick.AddItem("4", "NO");
	
	
	h_checkForMissclick.ExitButton = true;
	h_checkForMissclick.Display(client, MENU_TIME_FOREVER);
}

public int Handle_checkForMissclick(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0:ListBonusSettings(client);
				case 1:ListBonusSettings(client);
				case 2:db_deleteZonesInGroup(client);
				case 3:ListBonusSettings(client);
			}
		}
		case MenuAction_Cancel:
		{
			ListBonusSettings(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

public void listZonesInGroup(int client)
{
	Menu h_listBonusZones = new Menu(Handler_listBonusZones);
	if (g_mapZoneCountinGroup[g_CurrentSelectedZoneGroup[client]] > 0)
	{  // Types: Start(1), End(2), Stage(3), Checkpoint(4), Speed(5), TeleToStart(6), Validator(7), Chekcer(8), Stop(0)
		char listZoneName[256], ZoneId[64], Id[64];
		for (int i = 0; i < g_mapZonesCount; ++i)
		{
			if (g_mapZones[i][zoneGroup] == g_CurrentSelectedZoneGroup[client])
			{
				Format(ZoneId, sizeof(ZoneId), "%s-%i", g_szZoneDefaultNames[g_mapZones[i][zoneType]], g_mapZones[i][zoneTypeId]);
				IntToString(i, Id, sizeof(Id));
				Format(listZoneName, sizeof(listZoneName), ZoneId);
				h_listBonusZones.AddItem(Id, ZoneId);
			}
		}
	}
	else
	{
		h_listBonusZones.AddItem("", "No zones are available", ITEMDRAW_DISABLED);
	}
	h_listBonusZones.ExitButton = true;
	h_listBonusZones.Display(client, MENU_TIME_FOREVER);
}

public int Handler_listBonusZones(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char aID[64];
			GetMenuItem(tMenu, item, aID, sizeof(aID));
			g_ClientSelectedZone[client] = StringToInt(aID);
			g_CurrentZoneType[client] = g_mapZones[g_ClientSelectedZone[client]][zoneType]; 
			DrawBeamBox(client);
			g_Editing[client] = 2;
			if (g_ClientSelectedZone[client] != -1)
			{
				GetClientSelectedZone(client, g_CurrentZoneTeam[client], g_CurrentZoneVis[client]);
			}
			EditorMenu(client);
		}
		case MenuAction_Cancel:
		{
			ListBonusSettings(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}


public void renameBonusGroup(int client)
{
	if (!IsValidClient(client))
		return;
	
	PrintToChat(client, "[%cCK%c] Please write the bonus name in chat or use %c!cancel%c to stop.", MOSSGREEN, WHITE, MOSSGREEN, WHITE);
	g_ClientRenamingZone[client] = true;
}
// Types: Start(1), End(2), Stage(3), Checkpoint(4), Speed(5), TeleToStart(6), Validator(7), Chekcer(8), Stop(0)
public void SelectBonusZoneType(int client)
{
	Menu h_selectBonusZoneType = new Menu(Handler_selectBonusZoneType);
	h_selectBonusZoneType.SetTitle("Select Bonus Zone Type");
	
	h_selectBonusZoneType.AddItem("1", "Start");
	h_selectBonusZoneType.AddItem("2", "End");
	h_selectBonusZoneType.AddItem("3", "Stage");
	h_selectBonusZoneType.AddItem("4", "Checkpoint");
	
	h_selectBonusZoneType.ExitButton = true;
	h_selectBonusZoneType.Display(client, MENU_TIME_FOREVER);
}

public int Handler_selectBonusZoneType(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char aID[12];
			GetMenuItem(tMenu, item, aID, sizeof(aID));
			g_CurrentZoneType[client] = StringToInt(aID);
			if (g_bEditZoneType[client]) {
				db_selectzoneTypeIds(g_CurrentZoneType[client], client, g_CurrentSelectedZoneGroup[client]);
			}
			else
				EditorMenu(client);
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			SelectZoneGroup(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

// Create zone 2nd
public void SelectZoneGroup(int client)
{
	Menu newZoneGroupMenu = new Menu(h_newZoneGroupMenu);
	newZoneGroupMenu.SetTitle("Which zones do you want to create?");
	
	newZoneGroupMenu.AddItem("1", "Normal map zones");
	newZoneGroupMenu.AddItem("2", "Bonus zones");
	newZoneGroupMenu.AddItem("3", "Misc zones");
	
	newZoneGroupMenu.ExitButton = true;
	newZoneGroupMenu.Display(client, MENU_TIME_FOREVER);
}

public int h_newZoneGroupMenu(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0: // Normal map zones
				{
					g_CurrentSelectedZoneGroup[client] = 0;
					SelectNormalZoneType(client);
				}
				case 1: // Bonus Zones
				{
					g_CurrentSelectedZoneGroup[client] = -1;
					StartBonusZoneCreation(client);
				}
				case 2: // Misc zones
				{
					g_CurrentSelectedZoneGroup[client] = 0;
					SelectMiscZoneType(client);
				}
			}
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			ZoneMenu(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

public void StartBonusZoneCreation(int client)
{
	Menu CreateBonusFirst = new Menu(H_CreateBonusFirst);
	CreateBonusFirst.SetTitle("Create the Bonus Start Zone:");
	if (g_Editing[client] == 0)
		CreateBonusFirst.AddItem("1", "Start Drawing");
	else
	{
		CreateBonusFirst.AddItem("1", "Restart Drawing");
		CreateBonusFirst.AddItem("2", "Save Bonus Start Zone");
		
	}
	CreateBonusFirst.ExitButton = true;
	CreateBonusFirst.Display(client, MENU_TIME_FOREVER);
}

public int H_CreateBonusFirst(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0:
				{
					// Start
					g_Editing[client] = 10;
					float pos[3], ang[3];
					GetClientEyePosition(client, pos);
					GetClientEyeAngles(client, ang);
					TR_TraceRayFilter(pos, ang, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
					TR_GetEndPosition(g_fBonusStartPos[client][0]);
					StartBonusZoneCreation(client);
				}
				case 1:
				{
					if (!IsValidClient(client))
						return;
					
					g_Editing[client] = 2;
					PrintToChat(client, "[%cCK%c] Bonus Start Zone Created", MOSSGREEN, WHITE);
					EndBonusZoneCreation(client);
				}
			}
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			SelectZoneGroup(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

public void EndBonusZoneCreation(int client)
{
	Menu CreateBonusSecond = new Menu(H_CreateBonusSecond);
	CreateBonusSecond.SetTitle("Create the Bonus End Zone:");
	if (g_Editing[client] == 2)
		CreateBonusSecond.AddItem("1", "Start Drawing");
	else
	{
		CreateBonusSecond.AddItem("1", "Restart Drawing");
		CreateBonusSecond.AddItem("2", "Save Bonus End Zone");
	}
	CreateBonusSecond.ExitButton = true;
	CreateBonusSecond.Display(client, MENU_TIME_FOREVER);
}

public int H_CreateBonusSecond(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0:
				{
					// Start
					g_Editing[client] = 11;
					float pos[3], ang[3];
					GetClientEyePosition(client, pos);
					GetClientEyeAngles(client, ang);
					TR_TraceRayFilter(pos, ang, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
					TR_GetEndPosition(g_fBonusEndPos[client][0]);
					EndBonusZoneCreation(client);
				}
				case 1:
				{
					g_Editing[client] = 2;
					SaveBonusZones(client);
					ZoneMenu(client);
				}
			}
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			SelectZoneGroup(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

public void SaveBonusZones(int client)
{
	if ((g_fBonusEndPos[client][0][0] != -1.0 && g_fBonusEndPos[client][0][1] != -1.0 && g_fBonusEndPos[client][0][2] != -1.0) || (g_fBonusStartPos[client][1][0] != -1.0 && g_fBonusStartPos[client][1][1] != -1.0 && g_fBonusStartPos[client][1][2] != -1.0))
	{
		int id2 = g_mapZonesCount + 1;
		db_insertZone(g_mapZonesCount, 1, 0, g_fBonusStartPos[client][0][0], g_fBonusStartPos[client][0][1], g_fBonusStartPos[client][0][2], g_fBonusStartPos[client][1][0], g_fBonusStartPos[client][1][1], g_fBonusStartPos[client][1][2], 0, 0, g_mapZoneGroupCount);
		db_insertZone(id2, 2, 0, g_fBonusEndPos[client][0][0], g_fBonusEndPos[client][0][1], g_fBonusEndPos[client][0][2], g_fBonusEndPos[client][1][0], g_fBonusEndPos[client][1][1], g_fBonusEndPos[client][1][2], 0, 0, g_mapZoneGroupCount);
		PrintToChat(client, "[%cCK%c] Bonus Saved!", MOSSGREEN, WHITE);
	}
	else
		PrintToChat(client, "[%cCK%c] Failed to Save Bonus, error in coordinates", MOSSGREEN, WHITE);
	
	resetSelection(client);
	ZoneMenu(client);
	db_selectMapZones();
}

public void SelectNormalZoneType(int client)
{
	Menu SelectNormalZoneMenu = new Menu(Handle_SelectNormalZoneType);
	SelectNormalZoneMenu.SetTitle("Select Zone Type");
	SelectNormalZoneMenu.AddItem("1", "Start");
	SelectNormalZoneMenu.AddItem("2", "End");
	if (g_mapZonesTypeCount[g_CurrentSelectedZoneGroup[client]][3] == 0 && g_mapZonesTypeCount[g_CurrentSelectedZoneGroup[client]][4] == 0)
	{
		SelectNormalZoneMenu.AddItem("3", "Stage");
		SelectNormalZoneMenu.AddItem("4", "Checkpoint");
	}
	else if (g_mapZonesTypeCount[g_CurrentSelectedZoneGroup[client]][3] > 0 && g_mapZonesTypeCount[g_CurrentSelectedZoneGroup[client]][4] == 0)
	{
		SelectNormalZoneMenu.AddItem("3", "Stage");
	}
	else if (g_mapZonesTypeCount[g_CurrentSelectedZoneGroup[client]][3] == 0 && g_mapZonesTypeCount[g_CurrentSelectedZoneGroup[client]][4] > 0)
		SelectNormalZoneMenu.AddItem("4", "Checkpoint");
	
	SelectNormalZoneMenu.AddItem("5", "Start Speed");
	
	SelectNormalZoneMenu.ExitButton = true;
	SelectNormalZoneMenu.Display(client, MENU_TIME_FOREVER);
}

public int Handle_SelectNormalZoneType(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char aID[12];
			GetMenuItem(tMenu, item, aID, sizeof(aID));
			g_CurrentZoneType[client] = StringToInt(aID);
			if (g_bEditZoneType[client]) {
				db_selectzoneTypeIds(g_CurrentZoneType[client], client, 0);
			}
			else
				EditorMenu(client);
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			SelectZoneGroup(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

public void ZoneSettings(int client)
{
	Menu ZoneSettingMenu = new Menu(Handle_ZoneSettingMenu);
	ZoneSettingMenu.SetTitle("Global Zone Settings");
	switch (GetConVarInt(g_hZoneDisplayType))
	{	
		case 0:
			ZoneSettingMenu.AddItem("1", "Visible: Nothing");
		case 1:
			ZoneSettingMenu.AddItem("1", "Visible: Lower edges");
		case 2:
			ZoneSettingMenu.AddItem("1", "Visible: All sides");
	}

	switch (GetConVarInt(g_hZonesToDisplay))
	{
		case 1:
			ZoneSettingMenu.AddItem("2", "Draw Zones: Start & End");
		case 2:
			ZoneSettingMenu.AddItem("2", "Draw Zones: Start, End, Stage, Bonus");
		case 3:
			ZoneSettingMenu.AddItem("2", "Draw Zones: All zones");
	}
	ZoneSettingMenu.ExitButton = true;
	ZoneSettingMenu.Display(client, MENU_TIME_FOREVER);
}

public int Handle_ZoneSettingMenu(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0:
				{
					if (GetConVarInt(g_hZoneDisplayType) < 2)
					{
						SetConVarInt(g_hZoneDisplayType, (GetConVarInt(g_hZoneDisplayType) + 1));
					}
					else
						SetConVarInt(g_hZoneDisplayType, 0);
				}
				case 1:
				{
					if (GetConVarInt(g_hZonesToDisplay) < 3)
					{
						SetConVarInt(g_hZonesToDisplay, (GetConVarInt(g_hZonesToDisplay) + 1));
					}
					else
						SetConVarInt(g_hZonesToDisplay, 1);
				}
			}
			CreateTimer(0.1, RefreshZoneSettings, client, TIMER_FLAG_NO_MAPCHANGE);
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			ZoneMenu(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

public void SelectMiscZoneType(int client)
{
	Menu SelectZoneMenu = new Menu(Handle_SelectMiscZoneType);
	SelectZoneMenu.SetTitle("Select Misc Zone Type");
	
	SelectZoneMenu.AddItem("6", "TeleToStart");
	SelectZoneMenu.AddItem("7", "Validator");
	SelectZoneMenu.AddItem("8", "Checker");
	SelectZoneMenu.AddItem("0", "Stop");
	
	SelectZoneMenu.ExitButton = true;
	SelectZoneMenu.Display(client, MENU_TIME_FOREVER);
}

public int Handle_SelectMiscZoneType(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char aID[12];
			GetMenuItem(tMenu, item, aID, sizeof(aID));
			g_CurrentZoneType[client] = StringToInt(aID);
			if (g_bEditZoneType[client]) {
				db_selectzoneTypeIds(g_CurrentZoneType[client], client, 0);
			}
			else
				EditorMenu(client);
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			SelectZoneGroup(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}
// Types: Start(1), End(2), Stage(3), Checkpoint(4), Speed(5), TeleToStart(6), Validator(7), Chekcer(8), Stop(0)
public int Handle_EditZoneTypeId(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char selection[12];
			GetMenuItem(tMenu, item, selection, sizeof(selection));
			g_CurrentZoneTypeId[client] = StringToInt(selection);
			EditorMenu(client);
		}
		case MenuAction_Cancel:
		{
			SelectNormalZoneType(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

public void ListZones(int client, bool mapzones)
{
	Menu ZoneList = new Menu(MenuHandler_ZoneModify);
	ZoneList.SetTitle("Available Zones");
	
	char listZoneName[256], ZoneId[64], Id[64];
	if (g_mapZonesCount > 0)
	{  // Types: Start(1), End(2), Stage(3), Checkpoint(4), Speed(5), TeleToStart(6), Validator(7), Chekcer(8), Stop(0)
		if (mapzones)
		{
			for (int i = 0; i < g_mapZonesCount; ++i)
			{
				if (g_mapZones[i][zoneGroup] == 0 && 0 < g_mapZones[i][zoneType] < 6)
				{
					// Make stages match the stage number, rather than the ID, to make it more clear for the user
					if (g_mapZones[i][zoneType] == 3)
						Format(ZoneId, sizeof(ZoneId), "%s-%i", g_szZoneDefaultNames[g_mapZones[i][zoneType]], (g_mapZones[i][zoneTypeId] + 2));
					else
						Format(ZoneId, sizeof(ZoneId), "%s-%i", g_szZoneDefaultNames[g_mapZones[i][zoneType]], g_mapZones[i][zoneTypeId]);
					IntToString(i, Id, sizeof(Id));
					Format(listZoneName, sizeof(listZoneName), ZoneId);
					ZoneList.AddItem(Id, ZoneId);
				}
			}
		}
		else
		{
			for (int i = 0; i < g_mapZonesCount; ++i)
			{
				if (g_mapZones[i][zoneGroup] == 0 && (g_mapZones[i][zoneType] == 0 || g_mapZones[i][zoneType] > 5))
				{
					Format(ZoneId, sizeof(ZoneId), "%s-%i", g_szZoneDefaultNames[g_mapZones[i][zoneType]], g_mapZones[i][zoneTypeId]);
					IntToString(i, Id, sizeof(Id));
					Format(listZoneName, sizeof(listZoneName), ZoneId);
					ZoneList.AddItem(Id, ZoneId);
				}
			}
		}
	}
	else
	{
		ZoneList.AddItem("", "No zones are available", ITEMDRAW_DISABLED);
	}
	ZoneList.ExitButton = true;
	ZoneList.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ZoneModify(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char aID[64];
			GetMenuItem(tMenu, item, aID, sizeof(aID));
			g_ClientSelectedZone[client] = StringToInt(aID);
			g_CurrentZoneType[client] = g_mapZones[g_ClientSelectedZone[client]][zoneType];
			DrawBeamBox(client);
			g_Editing[client] = 2;
			if (g_ClientSelectedZone[client] != -1)
			{
				GetClientSelectedZone(client, g_CurrentZoneTeam[client], g_CurrentZoneVis[client]);
			}
			EditorMenu(client);
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			ZoneMenu(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

/*
g_Editing:
0: Starting a new zone, not yet drawing
1: Drawing a new zone
2: Editing paused
3: Scaling zone
10: Creating bonus start
11: creating bonus end
*/

public void EditorMenu(int client)
{
	// If scaling zone
	if (g_Editing[client] == 3)
	{
		DrawBeamBox(client);
		g_Editing[client] = 2;
	}
	
	Menu editMenu = new Menu(MenuHandler_Editor);
	// If a zone is selected
	if (g_ClientSelectedZone[client] != -1)
		editMenu.SetTitle("Editing Zone: %s-%i", g_szZoneDefaultNames[g_CurrentZoneType[client]], g_mapZones[g_ClientSelectedZone[client]][zoneTypeId]);
	else
		editMenu.SetTitle("Creating a New %s Zone", g_szZoneDefaultNames[g_CurrentZoneType[client]]);
	
	// If creating a completely new zone, or editing an existing one
	if (g_Editing[client] == 0)
		editMenu.AddItem("", "Start Drawing the Zone");
	else
		editMenu.AddItem("", "Restart the Zone Drawing");
	
	// If editing an existing zone
	if (g_Editing[client] > 0)
	{
		editMenu.AddItem("", "Set zone type");
		
		// If editing is paused
		if (g_Editing[client] == 2)
			editMenu.AddItem("", "Continue Editing");
		else
			editMenu.AddItem("", "Pause Editing");
		
		editMenu.AddItem("", "Delete Zone");
		editMenu.AddItem("", "Save Zone");
		
		switch (g_CurrentZoneTeam[client])
		{
			case 0:
			{
				editMenu.AddItem("", "Set Zone Yellow");
			}
			case 1:
			{
				editMenu.AddItem("", "Set Zone Green");
			}
			case 2:
			{
				editMenu.AddItem("", "Set Zone Red");
			}
			case 3:
			{
				editMenu.AddItem("", "Set Zone Blue");
			}
		}
		editMenu.AddItem("", "Go to Zone");
		editMenu.AddItem("", "Strech Zone");
		
		switch (g_CurrentZoneVis[client])
		{
			case 0:
			{
				editMenu.AddItem("", "Visibility: CT");
			}
			case 1:
			{
				editMenu.AddItem("", "Visibility: CT");
			}
			case 2:
			{
				editMenu.AddItem("", "Visibility: CT");
			}
			case 3:
			{
				editMenu.AddItem("", "Visibility: CT");
			}
		}
	}
	editMenu.ExitButton = true;
	editMenu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Editor(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0:
				{
					// Start
					g_Editing[client] = 1;
					float pos[3], ang[3];
					GetClientEyePosition(client, pos);
					GetClientEyeAngles(client, ang);
					TR_TraceRayFilter(pos, ang, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
					TR_GetEndPosition(g_Positions[client][0]);
					EditorMenu(client);
				}
				case 1: // Setting zone type
				{
					g_bEditZoneType[client] = true;
					if (g_CurrentSelectedZoneGroup[client] == 0)
						SelectNormalZoneType(client);
					else if (g_CurrentSelectedZoneGroup[client] > 0)
						SelectBonusZoneType(client);
					
				}
				case 2:
				{
					// Pause
					if (g_Editing[client] == 2)
					{
						g_Editing[client] = 1;
					} else {
						DrawBeamBox(client);
						g_Editing[client] = 2;
					}
					EditorMenu(client);
				}
				case 3:
				{
					// Delete
					if (g_ClientSelectedZone[client] != -1)
					{
						db_deleteZone(client, g_mapZones[g_ClientSelectedZone[client]][zoneId]);
					}
					resetSelection(client);
					ZoneMenu(client);
				}
				case 4:
				{
					// Save
					if (g_ClientSelectedZone[client] != -1)
					{
						if (!g_bEditZoneType[client])
							db_updateZone(g_mapZones[g_ClientSelectedZone[client]][zoneId], g_mapZones[g_ClientSelectedZone[client]][zoneType], g_mapZones[g_ClientSelectedZone[client]][zoneTypeId], g_Positions[client][0], g_Positions[client][1], g_CurrentZoneVis[client], g_CurrentZoneTeam[client], g_CurrentSelectedZoneGroup[client]);
						else
							db_updateZone(g_mapZones[g_ClientSelectedZone[client]][zoneId], g_CurrentZoneType[client], g_CurrentZoneTypeId[client], g_Positions[client][0], g_Positions[client][1], g_CurrentZoneVis[client], g_CurrentZoneTeam[client], g_CurrentSelectedZoneGroup[client]);
						g_bEditZoneType[client] = false;
					}
					else
					{
						db_insertZone(g_mapZonesCount, g_CurrentZoneType[client], g_mapZonesTypeCount[g_CurrentSelectedZoneGroup[client]][g_CurrentZoneType[client]], g_Positions[client][0][0], g_Positions[client][0][1], g_Positions[client][0][2], g_Positions[client][1][0], g_Positions[client][1][1], g_Positions[client][1][2], 0, 0, g_CurrentSelectedZoneGroup[client]);
						g_bEditZoneType[client] = false;
					}
					PrintToChat(client, "Zone saved");
					resetSelection(client);
					ZoneMenu(client);
				}
				case 5:
				{
					// Set team
					++g_CurrentZoneTeam[client];
					if (g_CurrentZoneTeam[client] == 4)
						g_CurrentZoneTeam[client] = 0;
					EditorMenu(client);
				}
				case 6:
				{
					// Teleport
					float ZonePos[3];
					ckSurf_StopTimer(client);
					AddVectors(g_Positions[client][0], g_Positions[client][1], ZonePos);
					ZonePos[0] = FloatDiv(ZonePos[0], 2.0);
					ZonePos[1] = FloatDiv(ZonePos[1], 2.0);
					ZonePos[2] = FloatDiv(ZonePos[2], 2.0);
					
					TeleportEntity(client, ZonePos, NULL_VECTOR, NULL_VECTOR);
					EditorMenu(client);
				}
				case 7:
				{
					// Scaling
					ScaleMenu(client);
				}
				case 8:
				{
					++g_CurrentZoneVis[client];
					switch (g_CurrentZoneVis[client])
					{
						case 1:
						{
							PrintToChat(client, "%t", "ZoneVisAll", MOSSGREEN, WHITE);
						}
						case 2:
						{
							PrintToChat(client, "%t", "ZoneVisT", MOSSGREEN, WHITE);
						}
						case 3:
						{
							PrintToChat(client, "%t", "ZoneVisCT", MOSSGREEN, WHITE);
						}
						case 4:
						{
							g_CurrentZoneVis[client] = 0;
							PrintToChat(client, "%t", "ZoneVisInv", MOSSGREEN, WHITE);
						}
					}
					EditorMenu(client);
				}
			}
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			ZoneMenu(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

public void resetSelection(int client)
{
	g_CurrentSelectedZoneGroup[client] = -1;
	g_CurrentZoneTeam[client] = 0;
	g_CurrentZoneVis[client] = 0;
	g_ClientSelectedZone[client] = -1;
	g_Editing[client] = 0;
	g_CurrentZoneTypeId[client] = -1;
	g_CurrentZoneType[client] = -1;
	g_bEditZoneType[client] = false;
	
	
	float resetArray[] =  { -1.0, -1.0, -1.0 };
	Array_Copy(resetArray, g_Positions[client][0], 3);
	Array_Copy(resetArray, g_Positions[client][1], 3);
	Array_Copy(resetArray, g_fBonusEndPos[client][0], 3);
	Array_Copy(resetArray, g_fBonusEndPos[client][1], 3);
	Array_Copy(resetArray, g_fBonusStartPos[client][0], 3);
	Array_Copy(resetArray, g_fBonusStartPos[client][1], 3);
}

public void ScaleMenu(int client)
{
	g_Editing[client] = 3;
	Menu ckScaleMenu = new Menu(MenuHandler_Scale);
	ckScaleMenu.SetTitle("Strech Zone");
	
	if (g_ClientSelectedPoint[client] == 1)
		ckScaleMenu.AddItem("", "Point B");
	else
		ckScaleMenu.AddItem("", "Point A");
	
	ckScaleMenu.AddItem("", "+ Width");
	ckScaleMenu.AddItem("", "- Width");
	ckScaleMenu.AddItem("", "+ Length");
	ckScaleMenu.AddItem("", "- Length");
	ckScaleMenu.AddItem("", "+ Height");
	ckScaleMenu.AddItem("", "- Height");
	
	char ScaleSize[128];
	Format(ScaleSize, sizeof(ScaleSize), "Scale Size %f", g_AvaliableScales[g_ClientSelectedScale[client]]);
	ckScaleMenu.AddItem("", ScaleSize);
	
	ckScaleMenu.ExitButton = true;
	ckScaleMenu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Scale(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0:
				{
					if (g_ClientSelectedPoint[client] == 1)
						g_ClientSelectedPoint[client] = 0;
					else
						g_ClientSelectedPoint[client] = 1;
				}
				case 1:
				{
					g_Positions[client][g_ClientSelectedPoint[client]][0] = FloatAdd(g_Positions[client][g_ClientSelectedPoint[client]][0], g_AvaliableScales[g_ClientSelectedScale[client]]);
				}
				case 2:
				{
					g_Positions[client][g_ClientSelectedPoint[client]][0] = FloatSub(g_Positions[client][g_ClientSelectedPoint[client]][0], g_AvaliableScales[g_ClientSelectedScale[client]]);
				}
				case 3:
				{
					g_Positions[client][g_ClientSelectedPoint[client]][1] = FloatAdd(g_Positions[client][g_ClientSelectedPoint[client]][1], g_AvaliableScales[g_ClientSelectedScale[client]]);
				}
				case 4:
				{
					g_Positions[client][g_ClientSelectedPoint[client]][1] = FloatSub(g_Positions[client][g_ClientSelectedPoint[client]][1], g_AvaliableScales[g_ClientSelectedScale[client]]);
				}
				case 5:
				{
					g_Positions[client][g_ClientSelectedPoint[client]][2] = FloatAdd(g_Positions[client][g_ClientSelectedPoint[client]][2], g_AvaliableScales[g_ClientSelectedScale[client]]);
				}
				case 6:
				{
					g_Positions[client][g_ClientSelectedPoint[client]][2] = FloatSub(g_Positions[client][g_ClientSelectedPoint[client]][2], g_AvaliableScales[g_ClientSelectedScale[client]]);
				}
				case 7:
				{
					++g_ClientSelectedScale[client];
					if (g_ClientSelectedScale[client] == 5)
						g_ClientSelectedScale[client] = 0;
				}
			}
			ScaleMenu(client);
		}
		case MenuAction_Cancel:
		{
			EditorMenu(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

public void GetClientSelectedZone(int client, int &team, int &vis)
{
	if (g_ClientSelectedZone[client] != -1)
	{
		Format(g_CurrentZoneName[client], 32, "%s", g_mapZones[g_ClientSelectedZone[client]][zoneName]);
		Array_Copy(g_mapZones[g_ClientSelectedZone[client]][PointA], g_Positions[client][0], 3);
		Array_Copy(g_mapZones[g_ClientSelectedZone[client]][PointB], g_Positions[client][1], 3);
		team = g_mapZones[g_ClientSelectedZone[client]][Team];
		vis = g_mapZones[g_ClientSelectedZone[client]][Vis];
	}
}

public void ClearZonesMenu(int client)
{
	Menu hClearZonesMenu = new Menu(MenuHandler_ClearZones);
	
	hClearZonesMenu.SetTitle("Are you sure, you want to clear all zones on this map?");
	hClearZonesMenu.AddItem("", "NO GO BACK!");
	hClearZonesMenu.AddItem("", "NO GO BACK!");
	hClearZonesMenu.AddItem("", "YES! DO IT!");
	
	hClearZonesMenu.Display(client, 20);
}

public int MenuHandler_ClearZones(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (item == 2)
			{
				for (int i = 0; i < MAXZONES; i++) 
				{
					g_mapZones[i][zoneId] = -1;
					g_mapZones[i][PointA] = -1.0;
					g_mapZones[i][PointB] = -1.0;
					g_mapZones[i][zoneId] = -1;
					g_mapZones[i][zoneType] = -1;
					g_mapZones[i][zoneTypeId] = -1;
					g_mapZones[i][zoneName] = 0;
					g_mapZones[i][Vis] = 0;
					g_mapZones[i][Team] = 0;
				}
				g_mapZonesCount = 0;
				db_deleteMapZones();
				PrintToChat(client, "Zones cleared");
				RemoveZones();
			}
			resetSelection(client);
			ZoneMenu(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}


stock void GetMiddleOfABox(const float vec1[3], const float vec2[3], float buffer[3])
{
	float mid[3];
	MakeVectorFromPoints(vec1, vec2, mid);
	mid[0] = mid[0] / 2.0;
	mid[1] = mid[1] / 2.0;
	mid[2] = mid[2] / 2.0;
	AddVectors(vec1, mid, buffer);
}

stock void RefreshZones()
{
	RemoveZones();
	for (int i = 0; i < g_mapZonesCount; i++)
	{
		CreateZoneEntity(i);
	}
}

stock void RemoveZones()
{
	// First remove any old zone triggers
	int iEnts = GetMaxEntities();
	char sClassName[64];
	for (int i = MaxClients; i < iEnts; i++)
	{
		if (IsValidEntity(i)
			 && IsValidEdict(i)
			 && GetEdictClassname(i, sClassName, sizeof(sClassName))
			 && StrContains(sClassName, "trigger_multiple") != -1
			 && GetEntPropString(i, Prop_Data, "m_iName", sClassName, sizeof(sClassName))
			 && StrContains(sClassName, "sm_ckZone") != -1)
		{
			SDKUnhook(i, SDKHook_StartTouch, StartTouchTrigger);
			SDKUnhook(i, SDKHook_EndTouch, EndTouchTrigger);
			AcceptEntityInput(i, "Disable");
			AcceptEntityInput(i, "Kill");
		}
	}
}
