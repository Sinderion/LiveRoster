FrameXML_Debug(enable)
-- TODO: RAID TEAMS/ROSTER
-- Todo: Get rid of warning about mains in loop.  Clicking main from main guild while in alt guild, should copy the main's name.
-- Achievement style toasts for invites? other things?

-- Debug
LREVERBOSE = 0;
LREDEBUG = 0;
LRLASTMEM = 0;

-- Snapshot
LR_USE_SNAPSHOT = 1; -- Enable creating or using a snapshot depending on if in main/alt guild
LRSNAPSHOT = LRSNAPSHOT or { Toons = { } }; 
LR_SnapshotIndex = {};

LiveRoster = { 
toons = {},
players = {}
}
LiveRoster.ExtensionButtons = {
Main = nil
}
LiveRoster["ExtensionSelection"] = nil;
LiveRoster.Roster = {
Mains = {},
Alts = {},
Unknown = {}
};
--LR_CACHED_OFFICERDETAILHEIGHT = GUILD_DETAIL_OFFICER_HEIGHT;
--LR_CACHED_NORMDETAILHEIGHT = GUILD_DETAIL_NORM_HEIGHT;
LR_CACHED_ADDMEMBER_ONACCEPT = nil;
LR_LOWESTRANK = GuildControlGetNumRanks() -1;
LR_HIDEFRAME = false;
LiveRoster_Selected_Promotion = 0;
LiveRoster_Selected_PromotionIndex = 0;
LiveRoster_Selected_AltPromotion = 0;
LiveRoster_Selected_AltPromotionIndex = 0;
LiveRoster_NumPromotions = 0;
LiveRoster_NumAltPromotions = 0;
LiveRosterCreated = false;
LiveRoster = { };
LiveRoster.Loaded = 0;
LR_ALTBUTTONTEXT = "Alt Promotions"
LR_DIRTY = nil;

function InAltGuild()

        local GuildName,_ = GetGuildInfo("Player")
        local Alty = 0;
        -- Quick hack to detect our alt guild. Only runs the first time update roster is run thanks to "LiveRosterCreated" variable.
        if GuildName == "Bastions of Twilight" then
            Alty = 1;
        else 
            Alty = nil;
        end
        return Alty;
end


function LRCreateRoster()
	--Roster = { }, 
    local i = 1;
    if LR_USE_SNAPSHOT > 0 and LRSNAPSHOT ~= nil and InAltGuild() then
       
        LRE("Snapshot found, using.");
        -- Good a place as any, being a single time use spot, to do initial unpacking of LRSNAPSHOT. i.e. making an indexed list pointing to the name indexes.
        
   

        for sName,vMain in pairs(LRSNAPSHOT.Toons) do
            LR_SnapshotIndex[i] = sName;
            i = i + 1;
        end


    end

    

	    LiveRoster.Players = { }; -- mostly links to mains, indexed by names
	    LiveRoster.Toons = { };
	    LiveRoster.ExtensionButtons = { };
	    LiveRoster.MostAlts = 0;
	    LiveRoster.OutputChannel = "SAY";
	    LiveRoster.SelectedPromotion = 0;
	    LiveRoster.PromotionsEnabled = 0;
	    LiveRoster.PlayerPromotions = 0;
	    LiveRoster.TotalPromotions = 0;
	    LiveRoster.SelectedPlayer = nil;
	    LiveRoster.SelectedAlt = 0; -- means main lol
	    LiveRoster.ShortNames = { };
	    LiveRoster.Roster = { }
	    LiveRoster.Roster.Mains = { };
	    LiveRoster.Roster.Alts = { };
	    LiveRoster.Roster.Unknown = { };	
	    LiveRoster.Roster.NameIndex = { };
	    LiveRoster.Roster.Promotions = { };
	    LiveRoster.Roster.NameIndex = { };
	    LiveRosterCreated = true;
        LiveRoster.MainGuildCount = i-1;
end
   
local myQuickInsert = table.insert;
local myQuickUpper = string.upper;

LiveRoster_InvitedToon = nil; -- For that space between invite and accept.
LiveRoster_InvitedAlt = nil;
--LiveRoster_AltFlag = false;
LiveRoster_InvitedAltMain = nil;
LiveRoster_RemovedToon = nil; -- Similar to above, to give the static popup time to do it's thing.
LiveRoster_ShowOffline = false; --save if we're showing offline or not while loading the roster.
LiveRoster_Bookmark = 0;
LiveRoster_SelectedToon = nil;


StaticPopupDialogs["LR_PROMOTION_CONFIRM"] = {
	text = "Set new rank?",--..LiveRoster.Roster[LiveRoster_Selected_PromotionIndex].ShortName.." to the rank of "..GuildControlGetRankName(LiveRoster.Roster.Promotions[LiveRoster_Selected_Promotion].NewRankIndex+1).."?",
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function(self)
		-- Queue up either an alt invite or main invite depending.
		SetGuildMemberRank(GetGuildRosterSelection(), LiveRoster.Roster.Promotions[LiveRoster_Selected_Promotion].NewRankIndex+1) --seems to need a +1
		GuildRoster_Update();
		LiveRoster.UpdateRoster();
		C_Timer.After(1,function(self) LiveRoster_NextPromotion(LiveRosterPromotionNext,"LeftButton"); PlaySound("LOOTWINDOWCOINSOUND"); LiveRoster.UpdateRoster(); end);
		
	end,
	OnShow = function(self)
	self.text:SetText("Promote "..LiveRoster.Roster[GetGuildRosterSelection()].ShortName.." to the rank of "..GuildControlGetRankName(LiveRoster.Roster.Promotions[LiveRoster_Selected_Promotion].NewRankIndex+1).."?");
	
	end,
	exclusive = 1,
	whileDead = 1,
	hideOnEscape = 1
	
}

StaticPopupDialogs["LR_ALT_PROMOTION_CONFIRM"] = {
	text = "Set new rank?",--..LiveRoster.Roster[LiveRoster_Selected_PromotionIndex].ShortName.." to the rank of "..GuildControlGetRankName(LiveRoster.Roster.Promotions[LiveRoster_Selected_Promotion].NewRankIndex+1).."?",
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function(self)
		-- Queue up either an alt invite or main invite depending.
		SetGuildMemberRank(GetGuildRosterSelection(), LiveRoster.AltPromotions[LiveRoster_Selected_AltPromotion].NewRankIndex+1) --seems to need a +1
		GuildRoster_Update();
		LiveRoster.UpdateRoster();
		C_Timer.After(1,function(self) LiveRoster_AltPromotion(LiveRosterPromotionAlts,"LeftButton"); PlaySound("LOOTWINDOWCOINSOUND") end);
		LiveRoster.AltPromotions = nil;
	end,
	OnShow = function(self)
	self.text:SetText("Promote "..LiveRoster.Roster[GetGuildRosterSelection()].ShortName.." to the rank of "..GuildControlGetRankName(LiveRoster.AltPromotions[LiveRoster_Selected_AltPromotion].NewRankIndex+1).."?");
	end,
	exclusive = 1,
	whileDead = 1,
	hideOnEscape = 1
}

StaticPopupDialogs["LR_SMART_ADD_GUILDMEMBER"] = {
	text = ADD_GUILDMEMBER_LABEL,
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	autoCompleteParams = AUTOCOMPLETE_LIST.GUILD_INVITE,
	maxLetters = 77,
	OnAccept = function(self)
		local player = self.editBox:GetText();
		local sName, sServer = string.split("-", player)
		if not sServer then player = sName.."-"..string.gsub(LRServer, " ", "") end
		-- Queue up either an alt invite or main invite depending.
		if LiveRoster_InvitedAltMain then
			LiveRoster_InvitedAlt=player;
		else
			LiveRoster_InvitedToon=player;
		end
		--LRE("Added: "..LiveRoster_InvitedToon);
		--C_Timer.After(3, function() LR_SystemMsg(LiveRoster_InvitedToon.." has joined the guild."); end);
		GuildInvite(self.editBox:GetText());
	end,
	OnShow = function(self)
		if LiveRoster_InvitedAltMain then
			self.text:SetText("Add alt for "..LiveRoster_InvitedAltMain);
		else
			self.text:SetText("Add New Main(Select main first to add alt)");
		end
		self.editBox:SetFocus();
	end,
	OnHide = function(self)
		ChatEdit_FocusActiveWindow();
		self.editBox:SetText("");
	end,
	EditBoxOnEnterPressed = function(self)
		local parent = self:GetParent();
		--GuildInvite(parent.editBox:GetText());
		LiveRoster_InvitedToon = parent.editBox:GetText()
		--LRE("Added: "..LiveRoster_InvitedToon);
		--C_Timer.After(3, function() LR_SystemMsg(LiveRoster_InvitedToon.." has joined the guild."); end);
		GuildInvite(LiveRoster_InvitedToon);
		parent:Hide();
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide();
	end,
	timeout = 0,
	exclusive = 1,
	whileDead = 1,
	hideOnEscape = 1
};


-- init depending on what you want to see.

-- goes with item quality colors
-- 1 - red, 2-- legendary, 3, 4 -- yellow, 5 - epic, down from there to 9 - grey

LIVEROSTER_RANK_COLORS = {

"FFFF0000","FFFF8000", "FFFFD700", "FFFFD700",  "FFa335EE", "FF0070DD", "FF1EFF00", "FFFFFFFF", "FF9D9D9D"

}
-- Rank 0 = guild master. 1  2  3  4    5    6   7   8 (0 and 9 don't need promotion data.)
LIVEROSTER_RANK_DAYS   = {0, 0, 0, 0, 274, 152, 60, 30}
LIVEROSTER_RANK_ACTIVE = {0, 0, 0, 0,   7,   7,  7,  6}

LIVEROSTER_CLASS_COLORS = {
Druid = "FFFF7D0A",
Hunter = "FFABD473",
Mage = "FF69CCF0",
Monk = "FF00FF96",
Paladin = "FFF58CBA",
Priest = "FFFFFFFF",
Rogue = "FFFFF569",
Shaman = "FF0070DE",
Warlock = "FF9482C9",
Warrior  = "FFC79C6E"
}

LIVEROSTER_CLASS_COLORS["Death Knight"] = "FFC41F3B";
LIVEROSTER_CLASS_COLORS["Demon Hunter"] = "FFA335EE";




--[[

-----========= A tale of six tables  ====-------

New format

Player is an object type more or less. Main and Alts in one.

LiveRoster[name] will get you the player object pointer.

First pass implementation of this:

LiveRoster.Roster[i].Alts is either nil or a list of alts directly pointed to by the main, stored in .mains right now.


1. LiveRoster.Players - Indexed by long name(player-server). Points to primary toons(mains) of whatever index.
2. LiveRoster.Toons - Indexed by long name, all of the toons.
3. LiveRoster.Roseter - indexed the same as guild roster when refreshed, points to .Toons objects directly.
3. LiveRoster.Roster.Mains - table of mains. Relevant info is stored on the .Toon object
4. LiveRoster.Roster.Alts - table of alts. Relevant info to alt status stored on the .Toon object.
5. LiveRoster.Promotions - Discovered promotions that may need doing based on TC promotion rules
				self.Roster.Promotions[j]["Offline"] = iTotalOffDays;
			   self.Roster.Promotions[j]["DaysInGuild"] = iDaysInGuild;
			   self.Roster.Promotions[j]["CurrentRank"] = LiveRoster.GetRankString(iRank);
			   self.Roster.Promotions[j]["NewRank"] = LiveRoster.GetRankString(iRank-1);
			   
]]--
--8888888888888888888888
-- LREVERBOSE  Debug and verbosity settings only sometimes used: 
-- Verbose levels: 3 (and 0) Verbose is for communicating roster and processing info, not debug.
--  3 = All the things + memory.
--  2 = idk yet, but 3 is nice number
--  1 = Normal alerts to text chat
--  0 = (default) No chat frame alerts.

-- LREDEBUG
-- Debug levels: 3 (and 0)
-- 3 = for tracing what's wrong, debug all the things! only implemented when neaded during development
-- 2 = for showing exceptional/niche events that would benefit from being learned from
--      like: 
--	  		  -new character before an update invited by someone else.
--	 		  -whatever else needs a wierd exception coded in.
-- 1 = All normal errors
-- 0 = nothing unless LRE() is called with no levels specified.


--Uses LREVERBOSE and LREDEBUG to determine whether to alert. if no level is given, alert anyways.

function LRE(sError, iDebug, iVerbose)

	iDebug = iDebug or 4;
	iVerbose = iVerbose or 0;



	sError = sError or "UNKNOWN_ERROR_AMG";

	-- This should mean LRE("Broken Link", 1) will show at level debug 1 and above
	--    and LRE("Odd Exception occurance in roster.", 0, 2) should work at debug 
	if (iVerbose > 0 and iVerbose <= LREVERBOSE) or (iDebug > 0 and iDebug <= LREDEBUG) or iDebug == 4 then
		DEFAULT_CHAT_FRAME:AddMessage("\124cFFFF0000Live Roster Error:\124r"..sError);
	end
		
end

function LiveRoster_Go()

	self = LiveRosterFrame;
	LRServer = GetRealmName();
	LRServer,_ = string.gsub(LRServer,"%s+", "")
	LRAP = 0;
	--if LiveRoster.Loaded == 0 then

		
		ShowUIPanel(GuildFrame);
		--SetGuildRosterSelection(0);
		--ShowOfflineBookmark = GuildRosterShowOfflineButton:GetChecked();
		SetCVar("guildRosterView","guildStatus");
		--C_Timer.After(2, function() LiveRosterFrameButtonNext:Enable(); LiveRosterFrameButtonSkip:Enable(); LiveRosterFrameEnablePromotions:Enable(); end)
		hooksecurefunc("GuildRoster_Update", LiveRoster.RosterUpdatePostHook)  --So we know when to add all the goodies to the guild roster
		hooksecurefunc("HybridScrollFrame_Update", LiveRoster.ScrollFrameUpdatePostHook);
		hooksecurefunc("GuildRosterViewDropdown_OnClick", LiveRoster.ViewMenuClickPostHook);
		GuildFrame:HookScript("OnLoad", GuildFrame_OnLoadHook );
		--hooksecurefunc("GuildInvite", LiveRoster.GuildInvitePostHook)
		--hooksecurefunc("StaticPopup_OnClick",LiveRoster.StaticPopup_OnClickPostHook)
		--GuildAddMemberButton:HookScript("OnClick", LiveRoster.GuildAddMemberButtonClickPostHook)
		--hooksecurefunc("StaticPopupDialogs.ADD_GUILDMEMBER.OnAccept",LiveRoster.AddMemberOnAcceptPostHook)
		LiveRoster_Main = self;
		self:RegisterEvent("ADDON_LOADED")
		self:RegisterEvent("VARIABLES_LOADED")
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("SAVED_VARIABLES_TOO_LARGE")
		self:RegisterEvent("CHAT_MSG_SYSTEM");
		--Just to try and trigger events.
		self:RegisterEvent("GUILD_ROSTER_UPDATE")
		self:RegisterEvent("FRIENDLIST_UPDATE")
		self:RegisterEvent("FRIENDLIST_SHOW")
		self:RegisterEvent("CHAT_MSG_CHANNEL_JOIN")
		self:RegisterEvent("CHAT_MSG_CHANNEL_LEAVE")
		self:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
		
	--end
		self:RegisterEvent("CHAT_MSG_SAY");
		self:RegisterEvent("CHAT_MSG_GUILD");
		self:RegisterEvent("VARIABLES_LOADED");
		self:RegisterEvent("PLAYER_ENTERING_WORLD");
		self:RegisterEvent("SAVED_VARIABLES_TOO_LARGE");
		self:RegisterEvent("CHAT_MSG_SYSTEM");
		--Just to try and trigger events.
		self:RegisterEvent("GUILD_ROSTER_UPDATE");
		self:RegisterEvent("FRIENDLIST_UPDATE");
		self:RegisterEvent("FRIENDLIST_SHOW");
		self:RegisterEvent("CHAT_MSG_CHANNEL_JOIN");
		self:RegisterEvent("CHAT_MSG_CHANNEL_LEAVE");
		self:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE");
	LiveRoster_PromoteButtonText = "Player Promotions";
	LR_ALTBUTTONTEXT = "Alt Promotions";
	LiveRosterSearchBox.autoCompleteParams = AUTOCOMPLETE_LIST_TEMPLATES.IN_GUILD
	--PlaySound("UChatScrollButton");
	--NavigatePromotions(-1);
	SLASH_LIVEROSTER1, SLASH_LIVEROSTER2 = '/liveroster','/lr' -- 3.
	
	LR_Player_Name = UnitName("player").."-"..LRServer;
	-- Search box needs some room.
	GuildRosterViewDropdown:SetPoint("TOPLEFT",GuildRosterFrame , "TOPLEFT", 150, -24);

	if not LRSETTINGS then 
			print("Didn't find LRSETTINGS");
			LRSETTINGS = {
			LIVEROSTER_RANK_COLORS = LIVEROSTER_RANK_COLORS,
			LIVEROSTER_RANK_DAYS   = LIVEROSTER_RANK_DAYS,
			LIVEROSTER_RANK_ACTIVE = LIVEROSTER_RANK_DAYS
			}
	else
		LRE("Found LRSETTINGS, trying to load.",1);
		LIVEROSTER_RANK_COLORS = LRSETTINGS.LIVEROSTER_RANK_COLORS;
		LIVEROSTER_RANK_DAYS   = LRSETTINGS.LIVEROSTER_RANK_DAYS
		LIVEROSTER_RANK_ACTIVE = LRSETTINGS.LIVEROSTER_RANK_DAYS
			
	end	
	
	-- Not even sure why this is necessary >.>
	
		for k, v in ipairs(LIVEROSTER_RANK_DAYS) do
			LIVEROSTER_RANK_DAYS[k] = tonumber(v);
		end	
		for k, v in ipairs(LIVEROSTER_RANK_ACTIVE) do
			LIVEROSTER_RANK_ACTIVE[k] = tonumber(v);
		end		
	--LiveRosterFramePictureBox:SetTexture("Interface\\Calendar\\Holidays\\Calendar_Fireworks")
	--LiveRosterFrameTitleFontstring:SetText("\124TInterface\\Icons\\misc_arrowleft:16");
	LiveRoster.UpdateRoster();
	LiveRoster.ShowOnline();

end

function LR_GetWords(str)
-- Thanks Guild greet people!
	local ret = {};
	local pos=0;
	local index=0
	while(true) do
		local word;
		_,pos,word=string.find(str, "^ *([^%s]+) *", pos+1);
		if(not word) then
			return ret;
		end
		ret[index]=word
		index = index+1
	end
end

function SlashCmdList.LIVEROSTER(msg, editbox) -- 4.


	if not msg then
		GuildFramePopup_Show(GuildRosterFrame)
	else
	
			local msgLower = string.lower(msg)
			local words = LR_GetWords(msg)
			local wordsLower = LR_GetWords(msgLower)
	
		
		if strmatch(msg,"^s$") then
			GuildFramePopup_Show(GuildFrame);
			LiveRosterSearchBox:SetText("");
			LiveRosterSearchBox:SetFocus();
	
		elseif strmatch(msg,"^s (.*)") then
		
			player = strmatch(msg,"^s (.*)")
			if player then

				local sName, sServer = string.split("-", player)
				if not sServer then player = sName.."-"..string.gsub(LRServer, " ", "") end
				
				
				if LiveRoster.Toons[player] then
					tToon = LiveRoster.Toons[player];
					
					--print("Yeah found "..tToon.Name);
					GuildFramePopup_Show(GuildFrame);
					--LiveRosterSearchBox:SetText("");
					LiveRosterSearchBox:SetFocus();
					LiveRosterSearchBox:SetText(tToon.Name)
					LR_SearchBox_OnEnterPressed(LiveRosterSearchBox);
					LR_ScrollTo(tToon.Index);
				else
				 print("Player not found. Format /lr s Character-ServerName (case-sensitive)")
				end
			end
		elseif strmatch(msg,"^rankdays$") or strmatch(msg,"^rd$") then
			print("Live Roster auto selects promotions based on days in guild and days offline.")
			print(" /lr rd lets you set the days in guild for each rank from rank 1 up to 9.")
			print("Rank 0 is Guild master. The higher the number, the lower the rank.")
			print("Example(my guild): /lr rd 0 0 0 0 274 152 60 30");
			print("Zero means no auto promotion. We have 4 officer type ranks and 5 ranks subject")
			print("to auto selected promotions.")
		elseif strmatch(msg,"^rankdays reset") or strmatch(msg,"^rd reset") then	
			LIVEROSTER_RANK_DAYS   = {0, 0, 0, 0, 274, 152, 60, 30}
			LRSETTINGS.LIVEROSTER_RANK_DAYS = LIVEROSTER_RANK_DAYS
			print("Live Roster auto-promotion selection rank days reset.")
		elseif strmatch(msg,"^rankdays ") or strmatch(msg,"^rd ") then
			--local myRanks = strmatch(msg,".+ (.+)");
			--local myRanks = string.split(myRanks, ",");
			local myRanks = words;
			for k, v in ipairs(LIVEROSTER_RANK_DAYS) do
				if tonumber(myRanks[k]) then
					LIVEROSTER_RANK_DAYS[k] = tonumber(myRanks[k]);
					LRSETTINGS.LIVEROSTER_RANK_DAYS[k] = tonumber(myRanks[k]);
					if tonumber(myRanks[k]) > 0 then
						print("Rank "..k.."("..GuildControlGetRankName(k+1)..") is matched for promotion at "..myRanks[k].." days in guild." )
					end
				end
			end
		
		elseif strmatch(msg,"^rankactivity$") or strmatch(msg,"^ra$") then
			print("Live Roster auto selects promotions based on days in guild and days offline.")
			print(" /lr ra lets you set the maximum days offline eligible for promotion.")
			print("Rank 0 is Guild master. The higher the number, the lower the rank.")
			print("Example(my guild): /lr ra 0 0 0 0 7 7 7 6");
			print("This means characters must have been online within a week to recieve increased ");
			print("guild priveleges on schedule.");
			print("Zero means no auto promotion. '/lr ra reset' will reset.")
			
		elseif strmatch(msg,"^rankactivity reset") or strmatch(msg,"^ra reset") then			
			
			LIVEROSTER_RANK_ACTIVE = {0, 0, 0, 0,   7,   7,  7,  6}
			LRSETTINGS.LIVEROSTER_RANK_ACTIVE = LIVEROSTER_RANK_ACTIVE;
			print("Live Roster activity settings reset.");
		elseif strmatch(msg,"^rankactivity ") or strmatch(msg,"^ra ") then
			--local myRanks = strmatch(msg,".+ (.+)");
			--local myRanks = string.split(myRanks, ",");
			local myDays = words;
			for k, v in ipairs(LIVEROSTER_RANK_DAYS) do
				if tonumber(myDays[k]) then
					LIVEROSTER_RANK_ACTIVE[k] = myRanks[k];
					LRSETTINGS.LIVEROSTER_RANK_ACTIVE[k] = myRanks[k];
					if tonumber(myRanks[k]) > 0 then
						print("Rank "..k.."("..GuildControlGetRankName(k+1)..") must have been online within "..myDays[k].." days to recieve promotion." )
					end
				end
			end
		elseif strmatch(msg,"^rankcolors$") or strmatch(msg,"^rc$") then
			
			print(" /lr rc lets you set the color for each rank from rank 1 up to 9.")
			print("Default is: /lr rc FFFF0000 FFFF8000 FFFFD700 FFFFD700 FFa335EE FF0070DD FF1EFF00 FFFFFFFF FF9D9D9D");
			print("Yeah... that's a lot. Those are UI Escape sequence color values.")
			print("DeathKnight(one word), blue, epic, and \"none\" ");
			print("are all valid options(CASE SENSITIVE).")
			print("Like: /lr rc red legendary default default epic rare uncommon common poor")
			print("(default is gold.) '/lr rc reset' will reset the colors.")
		elseif strmatch(msg,"^rankcolors reset") or strmatch(msg,"^rc reset") then
		
			LIVEROSTER_RANK_COLORS = {
"FFFF0000","FFFF8000", "FFFFD700", "FFFFD700",  "FFa335EE", "FF0070DD", "FF1EFF00", "FFFFFFFF", "FF9D9D9D"
}
LRSETTINGS.LIVEROSTER_RANK_COLORS = LIVEROSTER_RANK_COLORS;
			print("Live Roster rank colors reset.")
			LiveRoster.UpdateGuildRosterFrame();
		elseif strmatch(msg,"^rankcolors ") or strmatch(msg,"^rc ") then
		
		
			--local myRanks = strmatch(msg,".+ (.+)");
			--local myRanks = string.split(myRanks, ",");
			local myColors = words;
			for k, v in ipairs(LIVEROSTER_RANK_COLORS) do
				if myColors[k] then
					local myColorString = myColors[k];
	-- Substitutions for common Wow colors.
					-- Some basic colors
					if myColors[k] == "red" then
						myColors[k] = "FFFF0000"
					elseif myColors[k] == "blue" then
						myColors[k] = "FF0000FF"
					elseif myColors[k] == "green" then
						myColors[k] = "FF00FF00"
					elseif myColors[k] == "yellow" then
						myColors[k] = "FFFFFF00"
					elseif myColors[k] == "orange" then
						myColors[k] = "FFFFA500"						
					elseif myColors[k] == "white" then
						myColors[k] = "FFFFFFFF"
					elseif myColors[k] == "black" then
						myColors[k] = "FF000000"
					elseif myColors[k] == "pink" then
						myColors[k] = "FFFFC0CB"						
					elseif myColors[k] == "grey" then
						myColors[k] = "FF9D9D9D"		
											

					--classes
					elseif myColors[k] == "druid" then
						myColors[k] = "FFFF7D0A"
					elseif myColors[k] == "hunter" then
						myColors[k] = "FFABD473"
					elseif myColors[k] == "mage" then
						myColors[k] = "FF69CCF0"
					elseif myColors[k] == "monk" then
						myColors[k] = "FF00FF96"
					elseif myColors[k] == "paladin" then
						myColors[k] = "FFF58CBA"
					elseif myColors[k] == "priest" then
						myColors[k] = "FFFFFFFF"
					elseif myColors[k] == "rogue" then
						myColors[k] = "FFFFF569"
					elseif myColors[k] == "shaman" then
						myColors[k] = "FF0070DE"
					elseif myColors[k] == "warlock" then
						myColors[k] = "FF9482C9"
					elseif myColors[k] == "warrior" then
						myColors[k] = "FFC79C6E"
					elseif myColors[k] == "deathknight" then
						myColors[k] = "FFC41F3B"
					
					-- item quality
					elseif myColors[k] == "poor" then
						myColors[k] = "FF9D9D9D"
					elseif myColors[k] == "common" then
						myColors[k] = "FFFFFFFF"
					elseif myColors[k] == "uncommon" then
						myColors[k] = "FF1EFF00"
					elseif myColors[k] == "rare" then
						myColors[k] = "FF0070DD"
					elseif myColors[k] == "epic" then
						myColors[k] = "FFa335EE"
					elseif myColors[k] == "legendary" then
						myColors[k] = "FFFF8000"
					
					--default
					elseif myColors[k] == "default" then
						myColors[k] = "FFFFD700"	
					elseif myColors[k] and strlen(myColors[k]) ~= 8 or not strmatch(myColors[k],"^(%x+)$") then
						print("Unrecognized color: "..myColors[k]..", skipping that one.");
						print(" Colors must be lower case, or in format FFRRGGBB (rgb= red green blue)");
						print("red, green, blue, yellow, orange, pink, black/white/grey, item quality or class color");
						print("'none' will skip the rank, leaving it unchanged.");
						myColors[k] = "none";
					end
					
					if myColors[k] ~= "none" then
						LIVEROSTER_RANK_COLORS[k] = myColors[k];
						LRSETTINGS.LIVEROSTER_RANK_COLORS[k] = myColors[k];
						print("Rank "..k.."("..GuildControlGetRankName(k+1)..") is \124c"..myColors[k]..myColorString.."\124r.")
					end							

				end
			end -- of loop
			LiveRoster.UpdateGuildRosterFrame();
		
		else
			print("Live Roster - Guild roster enhancements.");
			print("  Try /lr by itself to open live roster.");
			print("    /lr rd will let you set promote dates.");
			print("    /lr ra will let you set promote activity.");
			print("    /lr rc will let you set rank colors in your guild roster.");
			print("    /lr s Sinderion-ShadowCouncil (example) take you directly to that player.");
		end
	
	end -- extra end for first check.
	--print("Looking for this person? "..strmatch(msg,"^s (.*)"));
end

function LiveRoster_OnEvent(self, event, ...)
	local arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13 = ...
	--LRE("Got an event!"..event);
	if (event == "ADDON_LOADED") and (arg1 == "LiveRoster") then
		LiveRoster_Main:UnregisterEvent("ADDON_LOADED");

		self:RegisterEvent("VARIABLES_LOADED");
		self:RegisterEvent("CHAT_MSG_SYSTEM");
		self:RegisterEvent("GUILD_ROSTER_UPDATE");

		if LiveRoster.Loaded == 0 then
			LiveRoster.UpdateRoster();
		end

	elseif (event == "VARIABLES_LOADED") then
		LiveRoster_Main:UnregisterEvent("VARIABLES_LOADED");
		if not LRSETTINGS then 
			--print("Didn't find LRSETTINGS");
			LIVEROSTER_RANK_COLORS = LIVEROSTER_RANK_COLORS
			LIVEROSTER_RANK_DAYS   = LIVEROSTER_RANK_DAYS
			LIVEROSTER_RANK_ACTIVE = LIVEROSTER_RANK_DAYS
			
		else
			--print("Found LRSETTINGS, trying to load.");
			LIVEROSTER_RANK_COLORS = LRSETTINGS.LIVEROSTER_RANK_COLORS;
			LIVEROSTER_RANK_DAYS   = LRSETTINGS.LIVEROSTER_RANK_DAYS
			LIVEROSTER_RANK_ACTIVE = LRSETTINGS.LIVEROSTER_RANK_DAYS
			-- Replace the guild greet function to load the roster, then force execution :D
			if LRSETTINGS and LRSETTINGS.GGF then
				--LRGGF()
				--GLDG_RosterImport()
			end
		end	
		
	elseif (event == "PLAYER_ENTERING_WORLD") then
		LiveRoster_Main:UnregisterEvent("PLAYER_ENTERING_WORLD")	
		if LiveRoster.Loaded == 0 then
			LiveRoster.UpdateRoster();
		end
		ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", LiveRoster_ChatFilter)
		
		self:RegisterEvent("CHAT_MSG_SYSTEM");
		
	elseif (event == "CHAT_MSG_SYSTEM") then
		LR_SystemMsg(arg1);
		
			
	elseif (event == "CHAT_MSG_SAY") then
		if arg1 == "add bitch" then
			StaticPopup_Show ("LR_SMART_ADD_GUILDMEMBER");
		end
	end
		
end



function LR_SystemMsg(msg)
	if msg == nil then return end
	LR_COMING_ONLINE 		= ".*%[(.+)%]%S*"..string.sub(ERR_FRIEND_ONLINE_SS, 20);
	LR_GOING_OFFLINE		= string.format(ERR_FRIEND_OFFLINE_S, "(.+)");
	LR_DECLINEINVITE	    = string.format(ERR_GUILD_DECLINE_S, "(.+)");
	LR_JOINED_GUILD			= string.format(ERR_GUILD_JOIN_S, "(.+)");
	LR_REMOVED			= string.format(ERR_GUILD_REMOVE_SS, "(.+)","(.+)");
	LR_AUTO_DECLINE = string.format(ERR_GUILD_DECLINE_AUTO_S, "(.+)");
	LR_PLAYERNOTFOUND = string.format(ERR_GUILD_PLAYER_NOT_FOUND_S, "(.+)");
	
	--GLDG_PROMO			= string.format(ERR_GUILD_PROMOTE_SSS, "(.+)", "(.+)", "(.+)")
	--GLDG_DEMOTE			= string.format(ERR_GUILD_DEMOTE_SSS, ".+", "(.+)", "(.+)")
	--GLDG_ACHIEVE    = string.format(ACHIEVEMENT_BROADCAST, "(.+)", "(.+)")
	-- Receiving system message
	LRE("incoming system message: "..msg, 1);
	-- Check players coming online
	local _, _, player = string.find(msg, LR_COMING_ONLINE)
	if player then
		local sName, sServer = string.split("-", player)
		if not sServer then player = sName.."-"..string.gsub(LRServer, " ", "") end
		if LiveRoster.Toons[player] then
			LiveRoster.Toons[player].Online = 1;
		end
		
		--LRE(player.." is now online yay!");
		
	end
	
	local _, _, player = string.find(msg, LR_GOING_OFFLINE)
	
	if player then
		local sName, sServer = string.split("-", player)
		if not sServer then player = sName.."-"..string.gsub(LRServer, " ", "") end
		if LiveRoster.Toons[player] then
			LiveRoster.Toons[player].Online = nil;
		end
		
		--LRE(player.." is now Offline amg!");
	end
	
	-- GOTTA MAKE ALL THE ALTS COMMENTS FIT AS WELL.
	
	
	--Toon is removed, make sure we keep any left over data.
	local _, _, player,_ = string.find(msg, LR_REMOVED)
	
	if player then
		local NewMain
		local sName, sServer = string.split("-", player)
		if not sServer then player = sName.."-"..string.gsub(LRServer, " ", "") end
		if LiveRoster.Toons[player] then
			
			-- If it's a main and it has alts, make another alt the main.
			  -- If it was an alt, update the main to show that.
			  --    ALL of this could be done with an update roster, but that pops up the guild frame >.<
			local OldToon = LiveRoster.Toons[player];
			
			if LiveRoster.Toons[player].isMain > 0 and #LiveRoster.Toons[player].Alts > 0 then
				
				NewMain = LiveRoster.Toons[player].Alts[1];
				-- Only actually do this when we're live.
				
				
				if CanEditPublicNote() then
					--GuildRosterSetPublicNote()
					--NewMain.Note = OldToon.Note;
					LRE("Set "..NewMain.Name.."'s public note to: "..OldToon.Note)
					
					LiveRoster_RegisterEdit(player, "PublicNote", OldToon.Note)
					C_Timer.After(0.5, LiveRoster_DoEdits);
					
				end
				
				-- Only do this when we're live
				NewMain.Alts = OldMain.Alts
				NewMain.isAlt = 0;
				LiveRoster.Players[OldToon.Name] = NewMain;
				tinsert(LiveRoster.Roster.Mains, NewMain.Index);
				NewMain.isMain = #LiveRoster.Roster.Mains;
				LiveRoster.Toons[OldToon.Name] = nil;
				-- Buh bye. /wave
				OldToon = nil;
			elseif OldToon.isAlt > 0  then
				LiveRoster.Toons[OldToon.Name] = nil;
			end
		end
	end
	
	local _, _, player = string.find(msg, LR_JOINED_GUILD)
	--local iInviteHandled = 0;
	if player then
		local sName, sServer = string.split("-", player)
		if not sServer then player = sName.."-"..string.gsub(LRServer, " ", "") end		
	--Universal stuff first		
		LiveRoster.Toons[player] = {
			Name = player, 
			Rank = GuildControlGetRankName(LR_LOWESTRANK), 
			Index = #LiveRoster.Roster, 
			RankIndex = LR_LOWESTRANK, 
			Class = "Druid", 
			Level = 100, 
			Note = " ",
			OfficerNote = " ",
			isMain = 0,
			isAlt = 0, 
			DaysInGuild = 0,
			ErrorStatus = 0,
			NeedsPromotion = 0,
			ShortName = sName,
			Online = 1,
			ClassFileName = "DRUID",
			Alts = nil
		}		
		
	--Now fix note.
		if LiveRoster_InvitedToon then
			local sName, sServer = string.split("-", LiveRoster_InvitedToon)
			if not sServer then Live_InvitedToon = sName.."-"..string.gsub(LRServer, " ", "") end		
			if player == LiveRoster_InvitedToon then
				-- He's the guy we invited
				local myName, sServer = string.split("-", UnitName("player"))
				
				if CanEditPublicNote() then
					--LiveRoster_RegisterEdit(player, "PublicNote", "Main"..myName.." "..date("%m/%d/%y"))
					--C_Timer.After(0.5, LiveRoster_DoEdits);
					if not GuildFrame:IsShown() then GuildFramePopup_Show(GuildRosterFrame) end
					GuildRosterShowOfflineButton:SetChecked(true);
					SetGuildRosterShowOffline(1);
					
					for i = 1, GetNumGuildMembers() do
						local sName,sRank,iRank,iLevel,sClass,_,sNote,sOfficerNote, Online,_, classFileName = GetGuildRosterInfo(i);
						if sName == player then
							SetGuildRosterSelection(i);
							LR_ScrollTo(i);
							GuildRosterSetPublicNote(i,"Main "..myName.." "..date("%m/%d/%y"));
							print("Live Roster: Updated comment for "..player.." to \"Main "..myName.." "..date("%m/%d/%y").."\".")
							LiveRoster.UpdateRoster();
							break;
						end
					
					end
				end
				iInviteHandled = 1;
				LRE(player.." joined yay! Setting note to: Main "..myName.." "..date("%m/%d/%y"), 1);
				LiveRoster_InvitedToon = nil
			end
		end
		
		if LiveRoster_InvitedAlt then
			local sName, sServer = string.split("-", LiveRoster_InvitedAlt)
			if not sServer then LiveRoster_InvitedAlt = sName.."-"..string.gsub(LRServer, " ", "") end		
			if player == LiveRoster_InvitedAlt then
				if CanEditPublicNote() then
					--LiveRoster_RegisterEdit(player, "PublicNote", LiveRoster.Players[LiveRoster_InvitedAltMain].ShortName.." Alt")
					--LiveRoster_DoEdits();
					if not GuildFrame:IsShown() then GuildFramePopup_Show(GuildRosterFrame) end
					GuildRosterShowOfflineButton:SetChecked(true);
					SetGuildRosterShowOffline(1);
					
					for i = 1, GetNumGuildMembers() do
						local sName,sRank,iRank,iLevel,sClass,_,sNote,sOfficerNote, Online,_, classFileName = GetGuildRosterInfo(i);
						if sName == player then
							LRE("Found invited alt after join.",1);
							SetGuildRosterSelection(i);
							LR_ScrollTo(i);
							GuildRosterSetPublicNote(i,LiveRoster.Players[LiveRoster_InvitedAltMain].ShortName.." Alt" );
							LiveRoster.UpdateRoster();
							break;
						end

					end
				end
				--Hook the alt to the main in .Alts and in .Players and in .Players[].Alts
				table.insert(LiveRoster.Players[LiveRoster_InvitedAltMain].Alts, LiveRoster.Toons[player])
				LiveRoster.Players[player] = LiveRoster.Toons[LiveRoster_InvitedAltMain];
				print("Live Roster: Updated comment for "..player.." to \""..LiveRoster.Toons[LiveRoster_InvitedAltMain].ShortName.." Alt\".");
				
				LiveRoster_InvitedAlt = nil;
				LiveRoster_InvitedAltMain = nil;
				iInviteHandled = 1;
				--Put comment in the toon's comment.
			end
		end
		--Deed is done, unlock the button
		if LiveRoster.ExtensionButtons and LiveRoster.ExtensionButtons.AddAltButton then LiveRoster.ExtensionButtons.AddAltButton:UnlockHighlight() end
		LRE(player.." has joined the guild yay!", 1);
		LiveRoster.UpdateRoster();
	end
--Declined accepted invite	
		local _, _, player = string.find(msg, LR_DECLINEINVITE)
	if player then
		local sName, sServer = string.split("-", player)
		if not sServer then player = sName.."-"..string.gsub(LRServer, " ", "") end		
		if LiveRoster_InvitedAlt then
			local sName, sServer = string.split("-", LiveRoster_InvitedAlt)
			if not sServer then LiveRoster_InvitedAlt = sName.."-"..string.gsub(LRServer, " ", "") end		
			if player == LiveRoster_InvitedAlt then
					--That means alt invite was declined manually.
					LiveRoster_InvitedAlt = nil;
					LiveRoster_InvitedAltMain = nil;
					--LiveRoster_AltFlag = false;
					StaticPopupDialogs.ADD_GUILDMEMBER.OnAccept = LR_CACHED_ADDMEMBER_ONACCEPT 
					LiveRoster.ExtensionButtons.AddAltButton:UnlockHighlight();
					LRE("Invite Declined, decline registered.", 1);
					
			end
		elseif LiveRoster_InvitedToon then
			local sName, sServer = string.split("-", LiveRoster_InvitedToon)
			if not sServer then LiveRoster_InvitedToon = sName.."-"..string.gsub(LRServer, " ", "") end		
			if player == LiveRoster_InvitedToon then
				--Invite declined manually 
				LiveRoster_InvitedToon = nil;
			end		
		end
	end
	
			local _, _, player = string.find(msg, LR_AUTO_DECLINE)
	if player then


		local sName, sServer = string.split("-", player)
		if not sServer then player = sName.."-"..string.gsub(LRServer, " ", "") end		
		if LiveRoster_InvitedAlt then
			local sName, sServer = string.split("-", LiveRoster_InvitedAlt)
			if not sServer then LiveRoster_InvitedAlt = sName.."-"..string.gsub(LRServer, " ", "") end		
			if player == LiveRoster_InvitedAlt then
					--That means alt invite was declined manually.
					LiveRoster_InvitedAlt = nil;
					LiveRoster_InvitedAltMain = nil;
					--LiveRoster_AltFlag = false;
					StaticPopupDialogs.ADD_GUILDMEMBER.OnAccept = LR_CACHED_ADDMEMBER_ONACCEPT
					LiveRoster.ExtensionButtons.AddAltButton:UnlockHighlight();
					LRE("Invite Auto Declined, decline registered.", 1);
					SendChatMessage("[Live Roster Auto-Reply]: Invite sent, but you're  set to automatically decline guild invites. Let us know when you're ready :D", "WHISPER", player);					
					
			end
		elseif LiveRoster_InvitedToon then
			local sName, sServer = string.split("-", LiveRoster_InvitedToon)
			if not sServer then LiveRoster_InvitedToon = sName.."-"..string.gsub(LRServer, " ", "") end		
			if player == LiveRoster_InvitedToon then
			-- Invitation auto declined
				SendChatMessage("[Live Roster Auto-Reply]: Invite sent, but you're  set to automatically decline guild invites. Let us know when you're ready :D", "WHISPER", player);					
				LiveRoster_InvitedToon = nil;
			end
		end
	
	end
	
	local _, _, player = string.find(msg, LR_PLAYERNOTFOUND)
	if player then
		local sName, sServer = string.split("-", player)
		if not sServer then player = sName.."-"..string.gsub(LRServer, " ", "") end		
		if LiveRoster_InvitedAlt then
			local sName, sServer = string.split("-", LiveRoster_InvitedAlt)
			if not sServer then LiveRoster_InvitedAlt = sName.."-"..string.gsub(LRServer, " ", "") end		
			if player == LiveRoster_InvitedAlt then
					--That means alt wasn't found, reset stuff.
					LiveRoster_InvitedAlt = nil;
					LiveRoster_InvitedAltMain = nil;
					LiveRoster_AltFlag = false;
					
					LiveRoster.ExtensionButtons.AddAltButton:UnlockHighlight();
					--LRE("Invite Auto Declined, decline registered.", 1);
					LRE("Not found, clearing.", 1);
					
					
			end
		elseif LiveRoster_InvitedToon then
			local sName, sServer = string.split("-", LiveRoster_InvitedToon)
			if not sServer then LiveRoster_InvitedToon = sName.."-"..string.gsub(LRServer, " ", "") end		
			
			if player == LiveRoster_InvitedToon then
			-- Toon wasn't found.
				
				LiveRoster_InvitedToon = nil;
				LRE("Not found, clearing.", 1);
			end
		end
	end
	
end

function GuildFrame_OnLoadHook(self)

	if CanGuildInvite() or CanGuildPromote() then LiveRosterFrame:Show() end 
 
 end

--For those times when you just can't edit at that time, 
--  like after system messages that might happen in combat
function LiveRoster_DoEdits()

	LiveRoster.PrepRoster();
   if LiveRoster.Edits then
	for k, v in pairs(LiveRoster.Edits) do
		if v.Edit == "Comment" then
		
			for i = 1, GetNumGuildMembers() do
				local sName,sRank,iRank,iLevel,sClass,_,sNote,sOfficerNote, Online,_, classFileName = GetGuildRosterInfo(i);
				if sName == player then
					--SetGuildRosterSelection(i);
					GuildRosterSetPublicNote(i, v.Value);
					C_Timer.After(0.5, LiveRoster.UpdateRoster);
					break;
				end
			end
		end	
	end
  end
 end

function LiveRoster_RegisterEdit(sPlayer, sEdit, xValue)

	if not LiveRoster.Edits then LiveRoster.Edits = {} end
	table.insert(LiveRoster.Edits, { Toon = sPlayer, Edit = sEdit, Value = xValue})

end

function LiveRoster.ViewMenuClickPostHook()
	
	GuildRoster();
	GuildRoster_Update();
	--LRE("clicked menu button!")
	LiveRoster.UpdateGuildRosterFrame()

end

function ExtensionButton_OnClick(self, button)
	
	if self:IsEnabled() then
		self:LockHighlight();
	end

  	
	if self.LongName =="Header" then 
	--nothing, it's disabled
	elseif self.LongName == "AddAltButton" then
	-- add a freaking alt yo!
		LRE("Adding an alt to "..LiveRoster.ExtensionButtons.Main.LongName, 1);
--If there's an alt invite already out, wait for it to happen.
		if LiveRoster_InvitedAlt then
			LRE("Alt invite pending for "..LiveRoster_InvitedAltMain);
		elseif LiveRoster_InvitedToon then
			LRE("Invite pending for "..LiveRoster_InvitedToon);
		else
			LiveRoster_InvitedAltMain = LiveRoster.ExtensionButtons.Main.LongName
			if ( StaticPopup_FindVisible("LR_SMART_ADD_GUILDMEMBER") ) then
				StaticPopup_Hide("LR_SMART_ADD_GUILDMEMBER");
			else
				StaticPopup_Show("LR_SMART_ADD_GUILDMEMBER");
			end
			--dunno if I need this.
			--LiveRoster_AltFlag = true;
			
			--LRE("Pretending to show add member. tossing ball to systemmsg handler.")
			--C_Timer.After(3, function() LR_SystemMsg(LiveRoster_InvitedAlt.." has joined the guild."); end);
		end
	else
		-- clickmepromote
	
		if LiveRoster.Loaded == 0 then return; end
		if CanGuildInvite() then
			if LiveRoster.ExtensionButtons and LiveRoster.ExtensionButtons.AddAltButton then
				LiveRoster.ExtensionButtons.AddAltButton:UnlockHighlight(); -- just in case ...
			end
		end
       
		LiveRoster.ExtensionSelection = self.LongName;
				LiveRoster.Loaded = 0; -- suspend operations until update roster reloads :D
		LiveRoster.UpdateRoster()
		LR_ScrollTo(GetGuildRosterSelection());
		if ( IsModifiedClick() ) then
			LiveRoster_NameCopy();
		else
			PlaySound("igCharacterInfoOpen");
		end
	end
end

function LiveRosterFrame_Onload(self)

					--print("Hi! I loaded!");
				--LoadAddOn("Blizzard_Calendar");
				self:Show()	
				C_Timer.After(1,LiveRoster_Go);
				--self:Hide();
				-- PowerWordTriviaButton:Show();
				--self:RegisterForDrag("LeftButton");
				self:SetPoint("TOPLEFT",GuildRosterFrame , "TOPLEFT", 331, -300);
				--self:SetScale(UIParent:GetScale());
				--self:RegisterForClicks("AnyUp");
				--self:SetScript("OnUpdate", function(self) LiveRosterFrameTitleFontstring:SetText("Live Roster Console"..floor(self:GetLeft()-GuildRosterFrame:GetLeft())..", "..floor(self:GetTop()-GuildRosterFrame:GetTop())) end)
				
				--LiveRosterFrameClose:Hide();
				if not CanGuildInvite() and not CanGuildPromote() then
					self:Hide();
				end
				-- Roster Management Automation has been disabled in 7.3 due to exploits. Hiding related button, hopefully just for now.
				self:Hide();

end

function LR_SearchBox_OnEnterPressed(self)

	player = self:GetText();
	AutoCompleteEditBox_OnEnterPressed(self)	
	local sName, sServer = string.split("-", player)
	
	if not sServer then player = sName.."-"..string.gsub(LRServer, " ", "") end		
	if player and LiveRoster.Toons[player] then
			GuildRosterShowOfflineButton:SetChecked(true);
			SetGuildRosterShowOffline(1);
			GuildRoster_Update();
			LiveRoster.ExtensionSelection = player;
			GuildFramePopup_Show(GuildMemberDetailFrame);
			LR_ScrollTo(LiveRoster.Toons[player].Index);
			--Open the box		
	end
	
	PlaySound("UChatScrollButton");
end

function LR_SearchBox_OnEditFocusLost(self)
	--AutoCompleteEditBox_OnEditFocusLost(self)
	SearchBoxTemplate_OnEditFocusLost(self)
end

function LR_SearchBox_OnLoad(self)
--SearchBoxTemplate_OnLoad(self);
	SearchBoxTemplate_OnLoad();
	
end

function LR_SearchBox_OnChange(self)
	SearchBoxTemplate_OnLoad(self);		
end
	--8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888

function LR_ScrollTo(iIndex, iDontExpand, iOffset)

	iDontExpand = iDontExpand or nil;
	iOffset = iOffset or 5;
	if not GuildFrame:IsShown() then
		GuildFramePopup_Show(GuildFrame);
	end
	
	-- Show offline members unless told otherwise.
	if not iDontExpand then 
		GuildRosterShowOfflineButton:SetChecked(true);
		SetGuildRosterShowOffline(1);
	end
	SetGuildRosterSelection(iIndex);
	local TooHigh = GetGuildRosterSelection()*(GuildRosterContainer.scrollBar.buttonHeight+2)-(GuildRosterContainer.scrollBar.buttonHeight*2)
	local JustRight = GetGuildRosterSelection()*(GuildRosterContainer.scrollBar.buttonHeight+2)-(GuildRosterContainer.scrollBar.buttonHeight*iOffset)
	local TooLow = GetGuildRosterSelection()*(GuildRosterContainer.scrollBar.buttonHeight+2)+(GuildRosterContainer.scrollBar.buttonHeight*2)
	---if GuildRosterContainer.scrollBar:GetValue() <
	GuildRosterContainer.scrollBar:SetValue(JustRight);						


end

function LiveRoster_NextPromotion_OnEnter(self)

						LiveRosterPromotionNext:SetWidth(190);
						LiveRosterPromotionNext:SetText(LiveRoster_PromoteButtonText);					
						--LiveRosterFramePictureBox:SetTexture("Interface\\Calendar\\Holidays\\Calendar_Fireworks");
						--LiveRosterFramePictureBox:SetWidth(185);
						GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
						GameTooltip:AddLine("Cycle main character promotions.", 0, 112/255, 221/255);
						GameTooltip:AddLine(" Click/Right click for Next/Previous player.");
						GameTooltip:AddLine(" To set recommended rank for selected player,");
						GameTooltip:AddLine(" use Shift + Click");
						
						GameTooltip:Show();
						

end

function LiveRosterButton_OnEnter(self)

						self:SetWidth(190);
						if not self.ExpandedText then self["Expanded Text"]="self.ExpandedText" end
						self:SetText(self.ExpandedText);					
						GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
						if not self.Tooltip then 
							GameTooltip:AddLine("Tooltip goes here.", 0, 112/255, 221/255);
							GameTooltip:AddLine("Fill out a function called self.Tooltip for tooltip lines only.");
						else
							self.Tooltip();
						end
						LiveRosterFrame:SetWidth(220);
						GameTooltip:Show();

end

function LiveRosterButton_OnLeave(self)

						self:SetWidth(30);
						LiveRosterFrame:SetWidth(80);
						if not self.Icon then
							self:SetText("|Tput\icon\here in self.Icon|t");
						else	
							self:SetText(self.Icon);
						end
						GameTooltip:Hide();
end

	--8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
	


function LiveRoster_AltPromotion(self, button)

	PlaySound("UChatScrollButton");
	if LiveRoster.Loaded == 0 then return; end
	
	
	if not GuildFrame:IsShown() then
		 ShowUIPanel(GuildFrame);
	end
	
	if LR_DIRTY then
		LiveRoster.UpdateRoster();
	end
	local player,_ = string.gsub(LR_Player_Name, " ", "")
	local myRank
	if LiveRoster.Players[player] and LiveRoster.Players[player].RankIndex then
		myRank = LiveRoster.Players[player].RankIndex;
	end
	--print("Player: "..player);	
	
--[[

--Alphabetical flat list, looks fluid on the main roster. SAVE as option later.
	if not LiveRoster.AltPromotions or LiveRoster_Selected_AltPromotion == 0 then
		LiveRoster.AltPromotions = { };
		local myQuickInsert = table.insert;
	
		local myRank = LiveRoster.Players[LR_Player_Name].RankIndex;
		for k, v in ipairs(LiveRoster.Roster.Alts) do
		
			if v.NeedsPromotion > 0 and v.Main.RankIndex > myRank then
				myQuickInsert(LiveRoster.AltPromotions, LiveRoster.Roster.Alts[k])
				if v.Main.RankIndex then -- it better have a main or shouldn't be q'd for promo...
					LiveRoster.Roster.Alts[k]["NewRankIndex"] = v.Main.RankIndex;
				end
			end
		end
		
	end
]]--	


--List sorted by mains, so it looks fluid on the mini roster.
	if not LiveRoster.AltPromotions or LiveRoster_Selected_AltPromotion == 0 then
		if not LiveRoster.AltPromotions then 
			LiveRoster.AltPromotions = { };
		else
			wipe(LiveRoster.AltPromotions);
		end
		local myQuickInsert = table.insert;
		--LiveRoster.Players[player].RankIndex;

		for k, v in pairs(LiveRoster.Roster.Mains) do
		
			if v.Alts then
				for i,j in ipairs(v.Alts) do
					if j.NeedsPromotion > 0 then
						myQuickInsert(LiveRoster.AltPromotions, LiveRoster.Roster.Mains[k].Alts[i]);
						if v.RankIndex then -- it better have a main or shouldn't be q'd for promo...
							LiveRoster.Roster.Mains[k].Alts[i]["NewRankIndex"] = v.RankIndex;
						end
					end				
				end		

			end
		end
		
	end
	
   GuildRosterShowOfflineButton:SetChecked(true);
   SetGuildRosterShowOffline(1);
      
   SortGuildRoster("level");
   SortGuildRoster("name");
	
	if button == "LeftButton" then
		if LiveRoster_Selected_AltPromotion < #LiveRoster.AltPromotions then
			
			if LiveRoster_NumAltPromotions > #LiveRoster.AltPromotions  then
			--They probably promoted someone since last roster updated, no increment so we don't skip a promotion
			else
				LiveRoster_Selected_AltPromotion = LiveRoster_Selected_AltPromotion + 1;
			end
			
		--SELECT SOMETHING PAST GUILDROSTERSELECTUION()
			
			LiveRoster.ExtensionSelection = nil; -- HouseCleaning.
			SetGuildRosterSelection(LiveRoster.AltPromotions[LiveRoster_Selected_AltPromotion].Index);
			LiveRoster_Selected_AltPromotionIndex = GetGuildRosterSelection();
			GuildFrame.selectedGuildMember=LiveRoster.AltPromotions[LiveRoster_Selected_AltPromotion].Index;
			GuildFramePopup_Show(GuildMemberDetailFrame);
			GuildRoster_Update();
			LR_ScrollTo(GetGuildRosterSelection());
						
		end
	elseif button == "RightButton" then
		if LiveRoster_Selected_AltPromotion > 1 then
			LiveRoster_Selected_AltPromotion = LiveRoster_Selected_AltPromotion - 1;
			
			LiveRoster.ExtensionSelection = nil; -- Just to clean things up.
			SetGuildRosterSelection(LiveRoster.AltPromotions[LiveRoster_Selected_AltPromotion].Index);
			LiveRoster_Selected_PromotionIndex = GetGuildRosterSelection();
			GuildFrame.selectedGuildMember=LiveRoster.AltPromotions[LiveRoster_Selected_AltPromotion].Index;
			GuildFramePopup_Show(GuildMemberDetailFrame);
			
			GuildRoster_Update();
			LR_ScrollTo(GetGuildRosterSelection());
		end
	elseif button == "MiddleButton" then
		--print("middle button")
		if LiveRoster_Selected_AltPromotion > 0 and LiveRoster_Selected_AltPromotionIndex > 0 then
			if GetGuildRosterSelection() ~= LiveRoster_Selected_AltPromotionIndex then
				
				LiveRoster.ExtensionSelection = nil; -- HouseCleaning.
				SetGuildRosterSelection(LiveRoster.AltPromotions[LiveRoster_Selected_AltPromotion].Index);			
				GuildFrame.selectedGuildMember=LiveRoster.AltPromotions[LiveRoster_Selected_AltPromotion].Index;
				GuildFramePopup_Show(GuildMemberDetailFrame);
				GuildRoster_Update();
				LR_ScrollTo(GetGuildRosterSelection());
				
			end
		--print("not poping up yet")
		--print("myrank: "..myRank);
		--print("selectedthing: "..LiveRoster_Selected_AltPromotionIndex);
		
		 if myRank and LiveRoster.Roster[LiveRoster_Selected_AltPromotionIndex] and LiveRoster.Roster[LiveRoster_Selected_AltPromotionIndex].RankIndex and LiveRoster.Roster[LiveRoster_Selected_AltPromotionIndex].RankIndex > myRank then
			--print("should popup")
			StaticPopup_Show("LR_ALT_PROMOTION_CONFIRM");
		 end
		else
			
			LiveRoster_AltPromotion(self, "LeftButton");
		end
	end
	--LiveRoster_NumPromotions = #LiveRoster.Roster.Promotions;
	LR_ALTBUTTONTEXT = "Alt Promotions ("..LiveRoster_Selected_AltPromotion.."/"..#LiveRoster.AltPromotions..")";
	if MouseIsOver(self) then
	 LiveRosterPromotionAlts:SetText(LR_ALTBUTTONTEXT);
	end
	LiveRoster_NumAltPromotions = #LiveRoster.AltPromotions

end

	--8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888


function LiveRoster_NextPromotion(self, button)

-- Animations for scrolling the guild roster(even not animation...)

	PlaySound("UChatScrollButton");
	if LiveRoster.Loaded == 0 then return; end
	
	
	if not GuildFrame:IsShown() then
		 ShowUIPanel(GuildFrame);
	end
	
	if LR_DIRTY then
		LiveRoster.UpdateRoster();
	end
	GuildRosterShowOfflineButton:SetChecked(true);
   SetGuildRosterShowOffline(1);
      
   SortGuildRoster("level");
   SortGuildRoster("name");

	if button == "LeftButton" then
		
		if IsModifiedClick() then
			if LiveRoster_Selected_Promotion > 0 and LiveRoster_Selected_PromotionIndex > 0 then
	
				if GetGuildRosterSelection() ~= LiveRoster_Selected_PromotionIndex then
			
					LiveRoster.ExtensionSelection = nil; -- HouseCleaning.
					SetGuildRosterSelection(LiveRoster.Roster.Promotions[LiveRoster_Selected_Promotion].Index);			
					GuildFrame.selectedGuildMember=LiveRoster.Roster.Promotions[LiveRoster_Selected_Promotion].Index;
					GuildFramePopup_Show(GuildMemberDetailFrame);
					GuildRoster_Update();
					LR_ScrollTo(GetGuildRosterSelection());
				
				end
			--LRE("Should show shit2.")
	
			--LRE("Should show shit.")
				StaticPopup_Show("LR_PROMOTION_CONFIRM");
			end
		else
		
	--LiveRoster_NumPromotions = #LiveRoster.Roster.Promotions;


			-- Move forward if we're not promoting	
			if LiveRoster_Selected_Promotion < #LiveRoster.Roster.Promotions then
		
				if LiveRoster_NumPromotions > #LiveRoster.Roster.Promotions and LiveRoster_Selected_Promotion > 0 then
			--They probably promoted someone since last roster updated, no increment so we don't skip a promotion
				else
					LiveRoster_Selected_Promotion = LiveRoster_Selected_Promotion + 1;
				end
			
		--SELECT SOMETHING PAST GUILDROSTERSELECTUION()
			
				LiveRoster.ExtensionSelection = nil; -- HouseCleaning.
				SetGuildRosterSelection(LiveRoster.Roster.Promotions[LiveRoster_Selected_Promotion].Index);
				LiveRoster_Selected_PromotionIndex = GetGuildRosterSelection();
				GuildFrame.selectedGuildMember=LiveRoster.Roster.Promotions[LiveRoster_Selected_Promotion].Index;
				GuildFramePopup_Show(GuildMemberDetailFrame);
				GuildRoster_Update();
				LR_ScrollTo(GetGuildRosterSelection());
						
			end --Bounds check
		end --Left click is modified or not
		
	elseif button == "RightButton" then
		if LiveRoster_Selected_Promotion > 1 then
			LiveRoster_Selected_Promotion = LiveRoster_Selected_Promotion - 1;
			
			LiveRoster.ExtensionSelection = nil; -- Just to clean things up.
			SetGuildRosterSelection(LiveRoster.Roster.Promotions[LiveRoster_Selected_Promotion].Index);
			LiveRoster_Selected_PromotionIndex = GetGuildRosterSelection();
			GuildFrame.selectedGuildMember=LiveRoster.Roster.Promotions[LiveRoster_Selected_Promotion].Index;
			GuildFramePopup_Show(GuildMemberDetailFrame);
			
			GuildRoster_Update();
			LR_ScrollTo(GetGuildRosterSelection());
		end
	end	

	--[[	Removing middle button, moving to left button if modifier button is clicked.
	elseif button == "MiddleButton" then

		if LiveRoster_Selected_Promotion > 0 and LiveRoster_Selected_PromotionIndex > 0 then
	
			if GetGuildRosterSelection() ~= LiveRoster_Selected_PromotionIndex then
			
				LiveRoster.ExtensionSelection = nil; -- HouseCleaning.
				SetGuildRosterSelection(LiveRoster.Roster.Promotions[LiveRoster_Selected_Promotion].Index);			
				GuildFrame.selectedGuildMember=LiveRoster.Roster.Promotions[LiveRoster_Selected_Promotion].Index;
				GuildFramePopup_Show(GuildMemberDetailFrame);
				GuildRoster_Update();
				LR_ScrollTo(GetGuildRosterSelection());
				
			end
			--LRE("Should show shit2.")
	
			--LRE("Should show shit.")
				StaticPopup_Show("LR_PROMOTION_CONFIRM");
			end
		else
			LiveRoster_NextPromotion(self, "LeftButton");
		end
	--LiveRoster_NumPromotions = #LiveRoster.Roster.Promotions;
	LiveRoster_PromoteButtonText = "Player Promotions ("..LiveRoster_Selected_Promotion.."/"..#LiveRoster.Roster.Promotions..")";
	if MouseIsOver(self) then
	 LiveRosterPromotionNext:SetText(LiveRoster_PromoteButtonText);
	 ]]--
	
	
			LiveRoster_PromoteButtonText = "Player Promotions ("..LiveRoster_Selected_Promotion.."/"..#LiveRoster.Roster.Promotions..")";
			if MouseIsOver(self) then
				LiveRosterPromotionNext:SetText(LiveRoster_PromoteButtonText);
			end


end


	--8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
	--8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
	--8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
	--8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888

--[[



88888888888 .d88888b.  .d88888b. 888   8888888888888888888888888b.  
    888    d88P" "Y88bd88P" "Y88b888       888      888  888   Y88b 
    888    888     888888     888888       888      888  888    888 
    888    888     888888     888888       888      888  888   d88P 
    888    888     888888     888888       888      888  8888888P"  
    888    888     888888     888888       888      888  888        
    888    Y88b. .d88PY88b. .d88P888       888      888  888        
    888     "Y88888P"  "Y88888P" 88888888  888    8888888888        
                                                                    

]]--


function ShowRosterTooltip(self)

	-- Figure out who we're looking at and get their main if possible
	if not self.guildIndex or self.guildIndex < 1 then
		return;
	end
	local sName, _, _, _, _, _, _, _,Online  = GetGuildRosterInfo(self.guildIndex);
	local tToon = LiveRoster.Toons[sName];
	local iCommentError = 0;
	local sSameRank = "\124cFFFF0000RankError\124r";
	local sCurrentRank = "\124cFFFF0000RankError\124r";
	
	if not sName or not tToon or not tToon.Name then
		return
	end
	

	--self = _G.GuildRosterContainerButton5;
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:AddLine("Related Characters", 0, 112/255, 221/255);

	GameTooltip:AddLine("Main and alts", 0, 1, 0);
	GameTooltip:AddLine(" ");
-- Get guildIndex, then get guild info, then look up by name...
	
	if not LiveRoster.Players[tToon.Name] then
		GameTooltip:AddDoubleLine("Main Unknown: "..tToon.Name, "Days in Guild Uknown", 1,1 ,1 , 1, 0, 0);
		iCommentError = 1;
	end
	
	
	if tToon.isAlt > 0 or tToon.isMain > 0 then
		tToon = LiveRoster.Players[tToon.Name] or tToon;
		
			if iCommentError == 0 then
				GameTooltip:AddDoubleLine("Main: ",tToon.DaysInGuild.." days in guild.", nil,nil ,nil , 0, 1, 0);
			else
				GameTooltip:AddDoubleLine("Character: ", "No known main found in \""..tToon.Note.."\"", nil,nil ,nil , 1, 0, 0);
			end
			local classColor = LIVEROSTER_CLASS_COLORS[tToon.Class];
			sSameRank = tToon.RankIndex
--- Main character line			
			if tToon.OfflineMonths > 2 then --Crappy, crazy way to show/check long offline times
				if classColor then --Make text grey instead of class color
					classColor = "ff9d9d9d\124TInterface\\Icons\\Spell_Frost_Stun:16\124t";
				else
					classColor = "FFFFFF00\124TInterface\\Icons\\Spell_Frost_Stun:16\124t";
				end
			end

			local rankColor = LIVEROSTER_RANK_COLORS[tToon.RankIndex];
			if rankColor and tToon.NeedsPromotion > 0 then
				rankColor = "\124TInterface\\Icons\\misc_arrowlup:16\124t\124c"..rankColor;
			elseif rankColor then
				rankColor = "\124c"..rankColor;
			else  --probably rank 0, guild master
				rankColor = "\124cFFFF0000";
			end
			-- Say online if this is the toon that's online. 	REWRITE BETTER WITH .Players STRUCTURE :D
			if tToon.Online then
				classColor = classColor.."\124TInterface\\Common\\ReputationStar:0:0:0:1:32:32:0:16:0:16\124t ";
			end

			if classColor then
				GameTooltip:AddDoubleLine("\124c"..classColor..tToon.Name, rankColor..GuildControlGetRankName(sSameRank+1).."\124r");
			else
				GameTooltip:AddDoubleLine(tToon.Name,  rankColor..GuildControlGetRankName(sSameRank+1).."\124r");
			end
			
		local iAltsLineAdded = 0;

		
		if tToon.isMain == -1 then
				--GameTooltip:AddDoubleLine("Main Unknown: "..tToon.Name, "Days in Guild Uknown", 1,1 ,1 , 1, 0, 0);
				iCommentError = 1;
		else
			
			
			local tToonCycler = tToon.Alts;
			
			for i, iAlt in pairs(tToonCycler) do
				
				if iAltsLineAdded == 0 then
							GameTooltip:AddLine(" ");
							if #tToonCycler > 1 then
								GameTooltip:AddDoubleLine("Alts:", #tToonCycler.." alts found.");
							else
								GameTooltip:AddDoubleLine("Alts:", "One alt found.");
							end
							iAltsLineAdded = 1;
				end
		
				if iAlt then
					--iToonIndex = LiveRoster.Roster.Alts[iAltIndex].Index
					--if iToonIndex then
					
						tToon = iAlt;
						local classColor = LIVEROSTER_CLASS_COLORS[tToon.Class];
						local sName, _, _, _, _, _, _, _,Online  = GetGuildRosterInfo(tToon.Index);

                        if sName == nil then Online = false end -- If we're using snapshot, this is easy hack to clean up tooltip XD

						sCurrentRank = tToon.RankIndex
						
-- Alt list
						if tToon.OfflineMonths > 2 then  --Crappy, crazy way to show/check long offline times
							if classColor then
								classColor = "ff9d9d9d\124TInterface\\Icons\\Spell_Frost_Stun:16\124t";
							else
								classColor = "FFFFFF00\124TInterface\\Icons\\Spell_Frost_Stun:16\124t";
							end
						end
						
						-- Say online if this is the toon that's online. 	REWRITE BETTER WITH .Players STRUCTURE :D
						if tToon.Online then
							classColor = classColor.."\124TInterface\\Common\\ReputationStar:0:0:0:1:32:32:0:16:0:16\124t ";--ChatFrame_GetMobileEmbeddedTexture(0/255, 255/255, 255/255);
						end
			
						
						
						if classColor then
							if sCurrentRank ~= sSameRank then
								GameTooltip:AddDoubleLine("\124c"..classColor..tToon.Name.."\124r", "\124cFFFF0000"..GuildControlGetRankName(sCurrentRank+1).."\124r");
								iCommentError = 2;
							else
								GameTooltip:AddDoubleLine("\124c"..classColor..tToon.Name.."\124r",  "\124cFF00FF00"..GuildControlGetRankName(sCurrentRank+1).."\124r");
							end
						else
							if sCurrentRank ~= sSameRank then
								GameTooltip:AddDoubleLine(tToon.Name, "\124cFFFF0000"..GuildControlGetRankName(sCurrentRank+1).."\124r");							
								iCommentError = 2;
							else
								GameTooltip:AddDoubleLine(tToon.Name, "\124cFF00FF00"..GuildControlGetRankName(sCurrentRank+1).."\124r");							
							end						
							
						end

				else
					DEFAULT_CHAT_FRAME:AddMessage("\124cFFFF0000Error:\124r iAltIndex is nil for some reason.");
					SendChatMessage("Error: iAltIndex is nil for some reason.");
				end
			end
		end
	else
			GameTooltip:AddDoubleLine("Character: ", "Comment unclear", nil,nil ,nil , 1, 0, 0);
			local classColor = LIVEROSTER_CLASS_COLORS[tToon.Class];
			if classColor then
				GameTooltip:AddLine("\124c"..classColor..tToon.Name.."\124r");
			else
				GameTooltip:AddLine(tToon.Name);
			end
			iCommentError = 3;
	end
	
	GameTooltip:AddLine(" ");
	if iCommentError == 0 or sSameRank == "Guild Leader" then
		GameTooltip:AddDoubleLine("Comment status:", "Healthy", nil,nil ,nil , 0, 1, 0);
	else
	
		if iCommentError == 2 then  -- Not all same rank
			if LiveRoster.Players[tToon.Name].RankIndex == 0 then -- Guild master, his alts should link to his main's rank.
				GameTooltip:AddDoubleLine("Comment status:", "\124cFFFF8000"..LiveRoster.Players[tToon.Name].Note.."\124", nil,nil ,nil );
			else
				GameTooltip:AddDoubleLine("Comment status:", "Inconsistent ranks", nil,nil ,nil , 1, 1, nil);
				GameTooltip:AddLine("Fix ranks for accurate promotion suggestions.");
			end
		elseif iCommentError == 3 then
			if LiveRoster.Players and LiveRoster.Players[tToon.name] and LiveRoster.Players[tToon.Name].RankIndex == 0 then -- Guild master
				GameTooltip:AddDoubleLine("Comment status:", "\124cFFFF8000"..LiveRoster.Players[tToon.Name].Note.."\124", nil,nil ,nil );
			else
				GameTooltip:AddDoubleLine("Comment status:", "W T F Mate?", nil,nil ,nil , 1, 0, 0);
			end
		
		else  -- Other error
			GameTooltip:AddDoubleLine("Comment status:", "Non-Compliant(Main character unclear)", nil,nil ,nil , 1, 0, 0);
		end
	end
	GameTooltip:Show();
	
end	

function HideRosterTooltip()

	GameTooltip:Hide();
	
end	

--8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888


function LiveRoster_DoExtensionButtons(myToon)

	-- If this func was called by a click on an extension button(mini roster), then they wouldn't need to send a toon, just set _SelectedToon
	LiveRosterSearchBox:ClearFocus(); --cheap way to make sure it looses focus at the right time only.
	myToon = myToon or LiveRoster_SelectedToon;

	local tToon;
	
	if myToon then
	 
	 tToon = myToon;
	
	else
		LRE("No character passed to buttons!");
		return;
	end	
	
	if LiveRoster.ExtensionButtons.Main then
		LiveRoster.ExtensionButtons.Main:Hide();
	end		
	
	for i = 1, #LiveRoster.ExtensionButtons do		
		LiveRoster.ExtensionButtons[i]:Hide();
	end		
	
	local ExtensionButton

	if tToon.isMain > 0 or tToon.isAlt > 0  then
		days = tToon.DaysInGuild;
		

		--Select the toon to use to make the buttons, a main if possible.
		if tToon.isMain > 0  then -- hyjacking the outer if/then for main character expanded frame
			-- Use this toon to make a frame
			--LRE("Checking Button");
	
		elseif tToon.isAlt > 0 then
		
			if not LiveRoster.Players[tToon.Name] then
			
				LRE("Couldn't find player lookup for: "..tToon.Name, 2);
			
			else
				 tToon = LiveRoster.Players[tToon.Name];
			end
		end
	
			-- Abort if we didn't find a main at all.
		if tToon and tToon.isMain == 0 then 
			if LiveRoster.ExtensionButtons.Main then
				LiveRoster.ExtensionButtons.Main:Hide();
				
			end
				--return;
		end
		local offset = -20;		

--Header		
		if LiveRoster.ExtensionButtons.Header then

			ExtensionButton = LiveRoster.ExtensionButtons.Header;
			ExtensionButton.LongName = "Header";
				
		else
				--LRE("No button!");
			ExtensionButton = CreateFrame("BUTTON", "LiveRosterHeaderButton", GuildMemberDetailFrame, "LiveRosterExtensionButtonTemplate");
			if not ExtensionButton then
					--LRE("button creation failed!");
			end

			
			ExtensionButton["LongName"] = "Header";
			LiveRoster.ExtensionButtons.Header = ExtensionButton;
					--button:ClearAllPoints();
			LiveRoster.ExtensionButtons.Header:SetPoint("TOPLEFT", GuildMemberDetailFrame , "TOPRIGHT");					
					
		end	

--Set up Header
		--ExtensionButton:SetWidth(250);
		ExtensionButton:Show();
		ExtensionButton.level:Show();
		ExtensionButton.string2:Show();
		ExtensionButton.string2:SetJustifyV("MIDDLE");
		ExtensionButton.string3:Show();
		ExtensionButton.string4:Show();
		ExtensionButton.note:Show();
		ExtensionButton.officernote:Show();
		ExtensionButton.offline:Show();
				
		GuildRosterButton_SetStringText(ExtensionButton.level, "lvl", true)
		GuildRosterButton_SetStringText(ExtensionButton.string2, "Cls", true)
		GuildRosterButton_SetStringText(ExtensionButton.string3, "Name", true)
		GuildRosterButton_SetStringText(ExtensionButton.string4, "Rank", true)
		ExtensionButton.icon:Hide();
		GuildRosterButton_SetStringText(ExtensionButton.note, "Public Note", true);
		GuildRosterButton_SetStringText(ExtensionButton.officernote, "Officer Note", true);
		ExtensionButton:Disable();
		
		
		
--Main, and the rest		
		if LiveRoster.ExtensionButtons.Main then

			ExtensionButton = LiveRoster.ExtensionButtons.Main;
			ExtensionButton.LongName = tToon.Name;
				
		else
				--LRE("No button!");
			ExtensionButton = CreateFrame("BUTTON", "LiveRosterMainButton", GuildMemberDetailFrame, "LiveRosterExtensionButtonTemplate");
			if not ExtensionButton then
					--LRE("button creation failed!");
			end
			ExtensionButton:SetScript("OnDoubleClick", LiveRoster_NameCopy);
			LiveRoster.ExtensionButtons = { };
			ExtensionButton["LongName"] = tToon.Name;
			LiveRoster.ExtensionButtons.Main = ExtensionButton;
					--button:ClearAllPoints();
			LiveRoster.ExtensionButtons.Main:SetPoint("TOPLEFT", GuildMemberDetailFrame , "TOPRIGHT", 0, -20);					
					
		end	
		
					ExtensionButton:SetPoint("TOPLEFT", GuildMemberDetailFrame , "TOPRIGHT",0, offset);					
		
		local MainButton = ExtensionButton;
		local MainToon = tToon;
		local offset = -20;
	
		if not tToon then
			LRE("You'll be sorry!");
		end
		local AltCount;
		local myAlts;
		if tToon.isMain > 0 then
			--AltCount = #tToon.Alts;
			myAlts = LiveRoster.Players[tToon.Name].Alts
		else
			AltCount = 1;
			myAlts = {  tToon};
		end
		
		local myMain = tToon;
		local myCheatTable = {};
		
		
		--sketchy, but trying to make sure of smooth operation even if this is an alt still.
		if tToon.isMain > 0 then
			table.insert(myCheatTable, tToon);
			
			for k, v in pairs(myMain.Alts) do table.insert(myCheatTable, v)end
			--myCheatTable = {tToon, myMain.Alts};
		else
			table.insert(myCheatTable,tToon);
			--myCheatTable = {tToon};
		end
		
		local i = 0;
			-- let the loop do 0 as main button, kind of a sloppy way of avoiding writing a new function for displaying each toon.
			
		if LiveRoster.AltPromotions and LiveRoster.AltPromotions[LiveRoster_Selected_AltPromotion] and LiveRoster.AltPromotions[LiveRoster_Selected_AltPromotion].Name then
			sAltPromotionName = LiveRoster.AltPromotions[LiveRoster_Selected_AltPromotion].Name;
						
		end
			
		GuildRoster();
		for key, tToon in pairs(myCheatTable) do
		-- for i= 0, AltCount do
			
			local myAltIndex, myIndex
				
			if i == 0 then
				
				if tToon.isMain < 1 then
					--tToon = {Index = -1, Name = tToon.Name};  -- very wierd and creepy way to hack in error detection...
					offset = -60;
					-- why not just make a seperate variable... yeah i'm a wierdo lol
				else
					offset = -20;
				end
					-- we're good to go!				
			else

				if i == 1 then 
					offset = -60; -- to move the alts well below the main
				else
					offset = offset - 20; -- height of the bar to stack the alts closer
				end

					
				if LiveRoster.ExtensionButtons[i] then
					ExtensionButton = LiveRoster.ExtensionButtons[i];					
					ExtensionButton.LongName = tToon.Name;
				else
					--LRE("No button!");
					ExtensionButton = CreateFrame("BUTTON", "LiveRosterExtensionButton"..i, GuildMemberDetailFrame, "LiveRosterExtensionButtonTemplate");
						
					if not ExtensionButton then
					LRE("button creation failed! Extension alt buttons.");
					end
					--ExtensionButton:SetScript("OnDoubleClick", LiveRoster_NameCopy);
					LiveRoster.ExtensionButtons[i] = ExtensionButton;
					ExtensionButton["LongName"] = tToon.Name;
				end	
			end -- of count check
			
			--Create the string that goes before rank if any
				
				
				if not ExtensionButton then
					LRE("No button! count = "..i);
				elseif tToon.Index == -1 then  --creepy wierd way to throw error
				
				else
					
					local rankColor = LIVEROSTER_RANK_COLORS[tToon.RankIndex] or "FFFF0000";
					if not tToon.NeedsPromotion then
					
					LRE("Name of busted toon?: "..type(tToon));
					
					elseif tToon.NeedsPromotion > 0 then
						rankColor = "\124TInterface\\Icons\\misc_arrowlup:16\124t\124c"..rankColor;
					else
						rankColor = "\124c"..rankColor;
					end
				
					ExtensionButton:SetPoint("TOPLEFT", GuildMemberDetailFrame , "TOPRIGHT",0, offset);					
					
					ExtensionButton:Show();
					ExtensionButton.level:Show();
					ExtensionButton.string2:Show();
					ExtensionButton.string3:Show();
					ExtensionButton.string4:Show();
					ExtensionButton.note:Show();
					ExtensionButton.officernote:Show();
					ExtensionButton.offline:Show();
				
					GuildRosterButton_SetStringText(ExtensionButton.level, tToon.Level, true)
					GuildRosterButton_SetStringText(ExtensionButton.string4, rankColor..GuildControlGetRankName(tToon.RankIndex+1).."\124r", true)
					ExtensionButton.icon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[tToon.ClassFileName]));
					GuildRosterButton_SetStringText(ExtensionButton.note, tToon.Note, true);
					GuildRosterButton_SetStringText(ExtensionButton.officernote, tToon.OfficerNote, true);
					local online;
					--\124TInterface\\Common\\ReputationStar:16\124t

                    -- Using the "Online" field to indicate in the mini roster that this is a character from the main guild. Otherwise just saying online or not :D
                   if tToon.IsSnapshot then
					    GuildRosterButton_SetStringText(ExtensionButton.string3, tToon.ShortName, true, tToon.ClassFileName)
						GuildRosterButton_SetStringText(ExtensionButton.offline, "\124cff9d9d9d".. "Main Guild".."\124r", true);
					elseif not tToon.Online then
					    GuildRosterButton_SetStringText(ExtensionButton.string3, tToon.ShortName, true, tToon.ClassFileName)
						GuildRosterButton_SetStringText(ExtensionButton.offline, "\124cff9d9d9d".. RecentTimeDate( 0, tToon.OfflineMonths, tToon.OfflineDays, 0 ).."\124r", true);
                    else
						GuildRosterButton_SetStringText(ExtensionButton.string3, "\124TInterface\\Common\\ReputationStar:15:15:0:-4:32:32:0:16:0:16\124t "..tToon.ShortName, true, tToon.ClassFileName)
						GuildRosterButton_SetStringText(ExtensionButton.offline, "\124cFFFFD700Online\124r", true);
					end
				end
				
			if ( mod(i, 2) == 0 ) then
				ExtensionButton.stripe:SetTexCoord(0.36230469, 0.38183594, 0.95898438, 0.99804688);
			else
				ExtensionButton.stripe:SetTexCoord(0.51660156, 0.53613281, 0.88281250, 0.92187500);
			end				
			
				--Manage the highlight
				if LiveRoster.ExtensionSelection and ExtensionButton.LongName == LiveRoster.ExtensionSelection then
					ExtensionButton:LockHighlight();
				else
						ExtensionButton:UnlockHighlight();
				end
				
				if tToon.Name == sAltPromotionName then
					ExtensionButton:LockHighlight();
				end
				
			i = i + 1;		
		end		-- of loop
			
--Set up Alt invite button if they can invite.

		if CanGuildInvite() then
			if LiveRoster.ExtensionButtons.AddAltButton then
	
				ExtensionButton = LiveRoster.ExtensionButtons.AddAltButton;
				ExtensionButton.LongName = "AddAltButton";
									LiveRoster.ExtensionButtons.AddAltButton:SetPoint("TOPLEFT", GuildMemberDetailFrame , "TOPRIGHT", 0, offset -20);					
			else	
				--LRE("No button!");
				ExtensionButton = CreateFrame("BUTTON", "LiveRosterAddAltButton", GuildMemberDetailFrame, "LiveRosterExtensionButtonTemplate");
				if not ExtensionButton then
					--LRE("button creation failed!");
				end
				--ExtensionButton:SetScript("OnDoubleClick", LiveRoster_NameCopy);
				--ExtensionButton:LockHighlight();
			
				ExtensionButton["LongName"] = "AddAltButton";
				LiveRoster.ExtensionButtons.AddAltButton = ExtensionButton;
					--button:ClearAllPoints();
				LiveRoster.ExtensionButtons.AddAltButton:SetPoint("TOPLEFT", GuildMemberDetailFrame , "TOPRIGHT", 0, offset -20);					
					
			end	

			--ExtensionButton:SetWidth(250);
			if i > 0 or myMain.isMain > 0 then
				ExtensionButton:Show();
			end
			ExtensionButton.level:Show();
			ExtensionButton.string2:Show();
			ExtensionButton.string3:Show();
			ExtensionButton.string4:Show();
			ExtensionButton.note:Show();
			ExtensionButton.officernote:Show();
			ExtensionButton.offline:Show();
				
			GuildRosterButton_SetStringText(ExtensionButton.level, " ", true)
			GuildRosterButton_SetStringText(ExtensionButton.string3, "|TInterface\\Icons\\Spell_ChargePositive:16\124tInvite an Alt", true)
			GuildRosterButton_SetStringText(ExtensionButton.string4, " ", true)
			ExtensionButton.icon:Hide();
			GuildRosterButton_SetStringText(ExtensionButton.note, " ", true);
			GuildRosterButton_SetStringText(ExtensionButton.officernote, " ", true);
		end
		-- Roster Management Automation has been disabled in 7.3 due to exploits. Hiding related button, hopefully just for now.
		LiveRoster.ExtensionButtons.AddAltButton:Hide();
				-- find this toon's alt.
	else
		
		--if LiveRoster.ExtensionButtons.Main then
		--	LiveRoster.ExtensionButtons.Main:Hide();
		--end
		
		
		if LiveRoster.ExtensionButtons.Main then

			ExtensionButton = LiveRoster.ExtensionButtons.Main;
			ExtensionButton.LongName = "AddNote";
				
		else
				--LRE("No button!");
			ExtensionButton = CreateFrame("BUTTON", "LiveRosterMainButton", GuildMemberDetailFrame, "LiveRosterExtensionButtonTemplate");
			if not ExtensionButton then
					--LRE("button creation failed!");
			end
			ExtensionButton:SetScript("OnDoubleClick", LiveRoster_NameCopy);
			LiveRoster.ExtensionButtons = { };
			ExtensionButton["LongName"] = "AddNote";
			LiveRoster.ExtensionButtons.Main = ExtensionButton;
					--button:ClearAllPoints();
			LiveRoster.ExtensionButtons.Main:SetPoint("TOPLEFT", GuildMemberDetailFrame , "TOPRIGHT", 0, -20);					
			
		end	
		
			ExtensionButton:Show();
			ExtensionButton.level:Hide();
			ExtensionButton.string2:Hide();
			ExtensionButton.string3:Show();
			ExtensionButton.string4:Show();
			ExtensionButton.note:Show();
			ExtensionButton.officernote:Show();
			ExtensionButton.offline:Show();
				
			GuildRosterButton_SetStringText(ExtensionButton.level, " ", true)
			GuildRosterButton_SetStringText(ExtensionButton.string3, "Format notes:", true)
			GuildRosterButton_SetStringText(ExtensionButton.string4, "-------Try: Main", true)
			ExtensionButton.icon:Hide();
			GuildRosterButton_SetStringText(ExtensionButton.note, "<mm/dd/yy> or", true);
			GuildRosterButton_SetStringText(ExtensionButton.officernote, "Alt <Main> ", true);		
					
	end

end

--8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
--8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
--8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
--8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888

--[[

888     8888888888b. 8888888b.        d8888888888888888888888888 
888     888888   Y88b888  "Y88b      d88888    888    888        
888     888888    888888    888     d88P888    888    888        
888     888888   d88P888    888    d88P 888    888    8888888    
888     8888888888P" 888    888   d88P  888    888    888        
888     888888       888    888  d88P   888    888    888        
Y88b. .d88P888       888  .d88P d8888888888    888    888        
 "Y88888P" 888       8888888P" d88P     888    888    8888888888 
                                                                 
                                                                 
                                                                 
88888888888888888b.        d8888888b     d8888888888888 
888       888   Y88b      d888888888b   d8888888        
888       888    888     d88P88888888b.d88888888        
8888888   888   d88P    d88P 888888Y88888P8888888888    
888       8888888P"    d88P  888888 Y888P 888888        
888       888 T88b    d88P   888888  Y8P  888888        
888       888  T88b  d8888888888888   "   888888        
888       888   T88bd88P     888888       8888888888888 

]]--

function LiveRoster.UpdateGuildRosterFrame()


	scrollFrame = GuildRosterContainer;
	if LiveRoster.Loaded == 0 then
		return;
		
	end
	local tRoster = LiveRoster.Roster;
	
	local offset = HybridScrollFrame_GetOffset(scrollFrame);
	local buttons = scrollFrame.buttons;
	local numButtons = #buttons;
	local button, index;
	local selectedGuildMember = GetGuildRosterSelection();
	local CurrentGuildView = GetCVar("guildRosterView");
	
	-- Here on out, we're mirroring GuildRoster_Update() as needed
	---------------------------------------------------------------------
	
	-- Update detail frame if necessary
	if ( selectedGuildMember > 0 ) then
		local k, sNote;
		local days = 0;
		k, _, _, _, _, _, sNote  = GetGuildRosterInfo(selectedGuildMember);
		local tToon = tRoster[tRoster.NameIndex[k]];
		if not tToon then  return end
		days = tToon.DaysInGuild;
		LiveRoster_SelectedToon = tToon;

		LiveRoster_DoExtensionButtons();
		
		-- Now work the guild roster icons into place.
	--this is where we work based on guild view
	
		if days > 0 then
			if tToon.NeedsPromotion > 0 and tToon.RankIndex > 0 then
				if tToon.isMain > 0 then
					local newRank = GuildControlGetRankName(tRoster.Promotions[tToon.NeedsPromotion].NewRankIndex+1); -- +1 because the function works from 1, but rank indexes work from 0 >.<
					PersonalNoteText:SetText(sNote.."\124cFF00FF00(Days: "..days.."="..newRank..".)\124r");
				elseif tToon.isAlt > 0 then
					local newRank 
					if tToon.NewRankIndex then   
						newRank = GuildControlGetRankName(tToon.NewRankIndex+1); 
					else 
						if tToon.Main and tToon.Main.RankIndex then
							newRank = GuildControlGetRankName(tToon.Main.RankIndex+1)
						else
							newRank = tToon.Main.RankIndex 
						end
					end
					PersonalNoteText:SetText(sNote.."\124cFF00FF00(Main's rank is ".. newRank..".)\124r");
				end
			else
				if tToon.RankIndex > 0 then
				
					PersonalNoteText:SetText(sNote.."\124cFF00FF00("..days.." Days in guild)\124r");
				end
			end
		elseif days < 0 then
		 LRE("Date error for "..tToon.Name..": Less than zero days in guild?")
		else
			if tToon.RankIndex > 0 and tToon.isAlt > 0 then
				PersonalNoteText:SetText(sNote.."\124cFFFF0000 (Unknown main.)\124r");
			end
		end
	end

	-- Now to scroll through all buttons in parallel with roster entries and figure out wtf to show.	
	for i = 1, numButtons do
	
		button = buttons[i];		
		index = offset + i;
		local rankPrefix;
		local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName, achievementPoints, achievementRank, isMobile = GetGuildRosterInfo(index);
		-- figure out if they need a promotion
			-- put icon by their rank if so.
		if index <= #tRoster and index > 0 then
	
			local tToon = tRoster[tRoster.NameIndex[name]];
			if not tToon then return end
			local myRankColor = LIVEROSTER_RANK_COLORS[tToon.RankIndex];
			
			if not myRankColor then
				myRankColor = "FFFF0000";
			end
			
			if tToon.NeedsPromotion > 0 then
				rankPrefix = "\124TInterface\\Icons\\misc_arrowlup:16\124t\124c"..myRankColor;
			else
				rankPrefix = "\124c"..myRankColor;
			end
			
			if tToon.ErrorStatus > 0 then
				rankPrefix = "\124TInterface\\Icons\\INV_Misc_QuestionMark:16\124t"..rankPrefix;
			end
			
			if CurrentGuildView =="guildStatus" then
				GuildRosterContainer.buttons[i].string2:SetText(rankPrefix..rank.."\124r")
			end
		
		end
			-- GuildRosterContainer.buttons[3].string2:SetText("\124TInterface\\Icons\\INV_Misc_QuestionMark:16\124tSerf")
	end
end

--8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888

function LiveRoster.ScrollFrameUpdatePostHook(self, numElements, totalHeight, displayedHeight)
	
	if self == GuildRosterContainer then  -- Game on!


			LiveRoster.UpdateGuildRosterFrame();

		end

end

--8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888

function LiveRoster.RosterUpdatePostHook()


	LiveRoster.UpdateGuildRosterFrame();

end

--8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888

-- Gets date from comment in TC style
function LiveRoster.GetTCDate(sGuildNote)
   
   --old matching line just in case:
   -- local iMonth, iDay, iYear = strmatch(sGuildNote,"(%d+)[/%-%.](%d+)[/%-%.](%d+)");
   
   local iMonth, iDay, iYear = strmatch(myQuickUpper(sGuildNote),"MAIN.-(%d+)[/%-%.](%d+)[/%-%.](%d+)");
   --Very sloppy attempt to normalize two digit vs 4 digit years. 15 to 2015 etc.
   if iYear and tonumber(iYear) < 2000 then
      iYear = iYear + 2000;
   end
   
	if iMonth == 0 and iDay == 0 and iYear == 0 then
		iMonth = nil;
		iDay = nil;
		iYear = nil;
	end
   
   return tonumber(iMonth), tonumber(iDay), tonumber(iYear)
   
end



-- find out if a comment string makes this toon an alt. returns the main's name for true, nul for false.
function LiveRoster.IsAlt(sGuildNote)
   local sMainName = " ";
   --SendChatMessage("got to else-- "..sGuildNote);
   sGuildNote = myQuickUpper(sGuildNote);
   
   local sMainName = strmatch(sGuildNote, "(.+) ALT");
   if sMainName then
      
	  --For when people write, for example, "Sinderion's Alt", drop the "'s"
      if strmatch(sMainName,"'S$")then
         sMainName = strmatch(sMainName,"(.+)'S"); 
         
      end
   else
      
      sMainName = strmatch(sGuildNote, "ALT (.+)");
   end
   
   --SendChatMessage("Main name declared: "..(sMainName or " "));
   local sAlternateMainName = strmatch(sGuildNote, "ALT (.+)");
   if sMainName and strmatch(sMainName, "Heza") then
	SendChatMessage("Found Heza!"..sMainName);
   end
   -- Returns main name. Outside function can alternately choose to get the alternate as well, if a choice is needed.
   return sMainName, sAlternateMainName;
   
end

function LiveRoster.PrepRoster()

	ShowUIPanel(GuildFrame);
   GuildFrame:Show();
   
   GuildFrameTab2:Click();
   --LRStoreView();
   --ShowOfflineBookmark = false;
   GuildRosterShowOfflineButton:SetChecked(true);
   SetGuildRosterShowOffline(1);
      
   SortGuildRoster("level");
   SortGuildRoster("name");


end

function LiveRoster.ShowOnline()

	ShowUIPanel(GuildFrame);
   GuildFrame:Show();
   
   GuildFrameTab2:Click();
   --LRStoreView();
   --ShowOfflineBookmark = false;
   GuildRosterShowOfflineButton:SetChecked(false);
   SetGuildRosterShowOffline(false);
      
   SortGuildRoster("level");
   SortGuildRoster("name");
   if (IsAddOnLoaded("ElvUI")) then
	HideUIPanel(GuildFrame)	
	end
   


end



--****************
--*********************
--****************************
--*************************************
--***********************************************
--**************************************************
--*********************************************************
--*************************************************************
--*****************************************************************
--*****************************************************************
--*************************************************************************
--********************************************************************************
--****************************************************************************************
--[[ 

888     8888888888b. 8888888b.        d8888888888888888888888888 
888     888888   Y88b888  "Y88b      d88888    888    888        
888     888888    888888    888     d88P888    888    888        
888     888888   d88P888    888    d88P 888    888    8888888    
888     8888888888P" 888    888   d88P  888    888    888        
888     888888       888    888  d88P   888    888    888        
Y88b. .d88P888       888  .d88P d8888888888    888    888        
 "Y88888P" 888       8888888P" d88P     888    888    8888888888 
                                                                 
                                                                 
                                                                 
8888888b.  .d88888b.  .d8888b.8888888888888888888888888888b.  
888   Y88bd88P" "Y88bd88P  Y88b   888    888       888   Y88b 
888    888888     888Y88b.        888    888       888    888 
888   d88P888     888 "Y888b.     888    8888888   888   d88P 
8888888P" 888     888    "Y88b.   888    888       8888888P"  
888 T88b  888     888      "888   888    888       888 T88b   
888  T88b Y88b. .d88PY88b  d88P   888    888       888  T88b  
888   T88b "Y88888P"  "Y8888P"    888    8888888888888   T88b 

]]--

  
 

function LiveRoster:UpdateRoster(iStart, iEnd, sOutputChannel)
   
   
   if  LiveRosterCreated == false then



		LRCreateRoster(); 

		LiveRosterCreated = true;
	end
		
    local bInAltGuild = InAltGuild(); --Create a local bool vs calling the function all the time. TONS of looping to do, no time to waste ;)


	LRE("Updating roster. Hope it's a good time.", 1)
   self = LiveRoster;
	self.Loaded = 0;  -- Some things are best not done during a roster update.
--Stat keeping for debug
	--local Matched_count = 0;
	--local Player_count = 0;

	 

   
   
	local LR_HIDEFRAME = not GuildFrame:IsShown();
   LiveRoster.PrepRoster();
   --SetGuildRosterSelection(1);
   
   
   
   local iTotalMembers,_ = GetNumGuildMembers();
   local iCurrentMonth = tonumber(date("%m"));
   local iCurrentYear = tonumber(date("%y"));
   local iCurrentDay = tonumber(date("%d"));
   
   
   --local iFoundOne =  0; -- Keeps track of first time action is required, time to fire up the engines if this hits 1
   --local iCountNoobs = 0; -- Temporary, but this is where count trackers go.
   
   local iToday = (tonumber(date("%Y"))-2000-5)*365.25+tonumber(date("%j"))+38; -- %j is day of the year, so we can skip the month and day calculations if using date() :D

   iStart = iStart or 1;
   iEnd = iEnd or iTotalMembers;
   
   --For use with snapshot, but if you aren't in alt guild, MainGuildCount will be zero anyways, so can run this without any expensive checking.
   iEnd = iEnd + LiveRoster.MainGuildCount
   

   sOutputChannel = sOutputChannel or "SAY"
   LiveRoster.OutputChannel = sOutputChannel;
	LiveRoster_Reused_Slots = 0;

    local myQuickInsert = table.insert;
	local myQuickUpper = string.upper;
	local myQuickStrMatch = strmatch;
	local myQuickSplit = string.split;
	--To track if it's time to reset main/alt lists, while still reusing the list.
	local iFirstMain = 0; 
	local iFirstAlt = 0;

	
	
	if LiveRoster.Roster.Mains then wipe(LiveRoster.Roster.Mains) end
	--[[
	for k, v in ipairs(LiveRoster.Roster.Promotions) do
		LiveRoster.Roster.Promotions[k] = nil;
	end
	]]--
	if not LiveRoster.Roster.Promotions then
		LiveRoster.Roster.Promotions = { };
	else
		wipe(LiveRoster.Roster.Promotions);
	end
	if LiveRoster.Roster.Alts then wipe(LiveRoster.Roster.Alts) end
   
   -- make local copies of the rank info to speed lookup
   RankDays = LIVEROSTER_RANK_DAYS;
   RankActivity = LIVEROSTER_RANK_ACTIVE;
   --RankNum = GuildControlGetNumRanks();
      
   if not LRSNAPSHOT then LRSNAPSHOT ={ Toons = {} } end
   if not LRSNAPSHOT.Toons then LRSNAPSHOT.Toons = { } end

   --if bInAltGuild and LRSNAPSHOT then
        -- LRE("Total number of records to scan = "..iEnd);
   --end

   -- Sort out alts and mains, then plug together if possible in next loop
   for i=iStart, iEnd do
      
      local sName,sRank,iRank,iLevel,sClass,_,sNote,sOfficerNote, Online,_, classFileName
      local bIsSnapshot = nil; --
	  -- SNAPSHOT bits. feed in snapshot data until we churn through it all.
      
      if bInAltGuild and LRSNAPSHOT and i > iTotalMembers then

         local tToon = LRSNAPSHOT.Toons[LR_SnapshotIndex[i-iTotalMembers]]
            -- feed in snapshot data, because we've still got some.
            sName = LR_SnapshotIndex[i-iTotalMembers]
            iRank = tToon.RankIndex
            sRank = GuildControlGetRankName(iRank);
            iLevel = tToon.Level
            sClass = tToon.Class
            sNote = tToon.Note
            sOfficerNote = tToon.OfficerNote
            Online = nil
            classFileName = tToon.classFileName;
            bIsSnapshot = 1; -- For use in other places. This record is archived from a visit to the main guild.
        

      else
          sName,sRank,iRank,iLevel,sClass,_,sNote,sOfficerNote, Online,_, classFileName = GetGuildRosterInfo(i);
      end

      local tToon, trash;

	  local sShortName,_ = myQuickSplit("-", sName)	  
	  
	  if self.Toons[sName] then
		LiveRoster_Reused_Slots = LiveRoster_Reused_Slots + 1;
			tToon = self.Toons[sName];
			tToon.Name = sName; 
			tToon.ShortName = sShortName;
			tToon.Rank = sRank; 
			tToon.Index = i;
			tToon.RankIndex = iRank;
			tToon.Class = sClass;
			tToon.Level = iLevel; 
			tToon.Note = sNote;
			tToon.OfficerNote = sOfficerNote;
			tToon.isMain = 0;
			tToon.isAlt = 0;
			tToon.DaysInGuild = 0;
			tToon.ErrorStatus = 0;
			tToon.Online = Online;
			tToon.ClassFileName = classFileName;
			tToon.NeedsPromotion = 0;
			tToon.Alts = nil;
            tToon.IsSnapshot = bIsSnapshot;
			
	  else
		self.Toons[sName] = {
			Name = sName, 
			Rank = sRank, 
			Index = i, 
			RankIndex = iRank, 
			Class = sClass, 
			Level = iLevel, 
			Note = sNote,
			OfficerNote = sOfficerNote,
			isMain = 0,
			isAlt = 0, 
			DaysInGuild = 0,
			ErrorStatus = 0,
			NeedsPromotion = 0,
			ShortName = sShortName,
			Online = Online,
			ClassFileName = classFileName,
			Alts = nil,
            IsSnapshot = bIsSnapshot
		}
	  end


      -- Pack up relevant LRSNAPSHOT data if we're in the main guild, overwriting as necessary w/ newest info.

      if not bInAltGuild then
  	   LRSNAPSHOT.Toons[sName] = {
            Main = nil,
            Class = sClass,
            Level = iLevel,
            RankIndex = iRank,
            Note = sNote,
            OfficerNote = sOfficerNote,
            classFileName = classFileName
       }
       end
		
     -- Utility lists --

	  tToon = self.Toons[sName];
	  self.Roster[i] = tToon;
	  LiveRoster.Roster.NameIndex[sName] = i; --for easy reverse lookup of index :D

	  sShortName = myQuickUpper(sShortName);		         --
		                                                     --  For easy look up by short name when reading alt comments     
      if not self.ShortNames then self.ShortNames = {} end   --       e.g. "Sinderion Alt" Even though Sinderion's name is Sinderion-ShadowCouncil
	  self.ShortNames[sShortName] = self.Toons[sName]		 --
	  

      -- Time in guild and time last online calculation. The basis of TC automatic promotion calculations. --

      trash, tToon["OfflineMonths"], tToon["OfflineDays"] = GetGuildRosterLastOnline(i); 
		
	  tToon.OfflineMonths = tToon.OfflineMonths or 0;
	  

      local iMonth, iDay, iYear =  LiveRoster.GetTCDate(tToon.Note);
	  
	  --try again for Kouko lol
	  if not iMonth and not iDay and not iYear then
		iMonth, iDay, iYear =  LiveRoster.GetTCDate(tToon.OfficerNote);
		if iRank == 0 then
			iMonth = 1;
			iDay = 1;
			iYear = 2005;
		end
	  end
      
      --Create a key/value for this main, prime the structure that might hold alts.
      
 
      -- Calculate days in guild for this main
      --self.Roster[i]["MonthsInGuild"] = 0;
      -- Calculating number of days since Wow was released, that this person joined this guild. Easy to compare this way :D
      
      
      -- Time in service handled, time for activity check.
      
      local iOffYears,iOffMonths,iOffDays = GetGuildRosterLastOnline(i);
      iOffYears, iOffMonths, iOffDays = iOffYears and iOffYears or 0, iOffMonths or 0, iOffDays and iOffDays or 0;
      local iTotalOffDays =  iOffMonths*30.5 + iOffDays;
	  
      tToon["OfflineDays"] = iTotalOffDays;
	  tToon["NeedsPromotion"] = 0;
	  
	  local iPendingPromotion = 0;
      
      if iMonth and iDay and iYear then -- That means it's a main. If we're in the alt guild, by definition, it's not a main.
      
        
        -- Indicate this is a main in the snapshot.  nil = error, 1 = confirmed main, string = an alt of the named main contained in the string.
        if not bInAltGuild then
            tSnapshotToon = LRSNAPSHOT.Toons[sName]
            tSnapshotToon.Main = 1
        end

		if not LiveRoster.Roster.Mains then
			LiveRoster.Roster.Mains = { }
		end
		
		myQuickInsert(LiveRoster.Roster.Mains, tToon);
		-- SORT IT LATER WITH A FUNC THAT SAYS .SORT(TABLE, SORTFUNC) -- SORTFUNC() ITEMA.nAME > ITEMB.NAME
		local iMainIndex
		--Restart if this is new roster.
		if iFirstMain == 1 then
			iMainIndex = #LiveRoster.Roster.Mains +1;
		else
			iMainIndex = 1;
			iFirstMain = 1;			
		end
			
			--Stats keeping, should count as a 'match' if it's a main.	
			--Matched_count = Matched_count + 1;
		--This is a main, so needs to be in the ShortName's index.
		
		--Uppercase Short name since it should be case insensitive

		
			--store this toon's place in the .Main list in it's "isMain" value.
			tToon.isMain = iMainIndex;
			if not tToon.Alts then
				tToon.Alts = { };
			end
			self.Players[sName] = tToon;

		
		if tonumber(iYear) <2000 then LRE("Year too low!") end
		if tonumber(iMonth) > 12 or tonumber(iDay) > 31 then LRE("Date wierd for: "..tToon.Name.."! iDay: "..iDay.." iMonth: "..iMonth) end
     
		
		 
		 

		-- Best time calculation I can come up with :D 
		iToday = time();
		iJoinDay = time({year = iYear, month = iMonth, day = iDay});
		iDifference = difftime(iToday,iJoinDay);
		--  seconds to days.. seconds/60 per minute, 60 mins/hour, 24 hrs/day
		iDaysInGuild = floor(iDifference/60/60/24);
		--end
				
		
		
		tToon.DaysInGuild = iDaysInGuild;		
		
-- ==========  PROMOTION SELECTION	=========== --
		
		for k, v in ipairs(RankDays) do 

			if v > 0 and iPendingPromotion == 0 then
		
				if iRank > k and iDaysInGuild > v then 
					if iOffMonths == 0 and iOffDays < RankActivity[k] then
						-- SendChatMessage("Suggested promotion to Bannerman for "..sName.." Reason: More than nine months in guild, offline for "..iOffDays.." day(s), but ranked as "..sRank, self.OutputChannel);
						myQuickInsert(self.Roster.Promotions, i);
						local j = #self.Roster.Promotions;
						self.Roster.Promotions[j] = { };
						self.Roster.Promotions[j]["Index"] = i;
						self.Roster.Promotions[j]["Offline"] = iTotalOffDays;
						self.Roster.Promotions[j]["DaysInGuild"] = iDaysInGuild;
						self.Roster.Promotions[j]["CurrentRank"] = GuildControlGetRankName(iRank+1);
						self.Roster.Promotions[j]["NewRankIndex"] = k;
						--self.Roster.Promotions[]
						-- Highest promotion selected, break loop.
						iPendingPromotion = k;
						--Debug of promotion settings.
						LRE("Promotion selected. iRank: "..iRank.." k: "..k.." v: "..v.." iDaysInGuild: "..iDaysInGuild,3)
						break;
					end
				end
			end
		
		end
	
	else
	

		if LiveRoster.IsAlt(sNote) then

			tToon.isAlt = 1;	
			if tToon.Alts then tToon.Alts = nil; end
			tToon.isMain = -1;	 -- Error, main Unknown
			tToon["Main"] = nil;
			tToon.ErrorStatus = 2; -- default to no main error, fixed later :D

			if not LiveRoster.Roster.Alts then LiveRoster.Roster.Alts = { } end
			myQuickInsert(LiveRoster.Roster.Alts, tToon);
			tToon["Main"] = 0
			
			
		else
		
			if tToon.RankIndex > 0 then  --Guild Master can make his comment wtf ever lol
				tToon.ErrorStatus = 1;  -- 1 = no alt or main 2 = alt without main i guess.
			end
			
		end

        	
		
	end
		 if iPendingPromotion > 0 then
			tToon.NeedsPromotion = #self.Roster.Promotions;
			LiveRoster.PlayerPromotions = LiveRoster.PlayerPromotions +1;
			LiveRoster.TotalPromotions = LiveRoster.TotalPromotions +1;
		end

  
      
      
      
      
      
      -- SendChatMessage(self.Roster[i].Name..": ".."Month: "..iMonth.. " Day: ".. iDay.. " Year: ".. iYear.." Rank: " ..self.Roster[i].Rank);
   end -- OF FIRST LOOP

	if LR_HIDEFRAME == true then GuildFrame:Hide() end
	

      
      
--[[

for each alt, look through the mains for the name attached.

	if name found in either main or alternate name, fill in proper index
	
that's it.

]]--
--SendChatMessage("Calculating Main-Alt relationships...");
local myQuickInsert = table.insert;
local myQuickUpper = string.upper;	


--HOW ABOUT JUST TABLE.REMOVE()?
	if not LiveRoster.Roster.Alts then
		LiveRoster.Roster.Alts = { }
	
	end
	
	
	for iAltIndex, iAlt in ipairs(LiveRoster.Roster.Alts) do
		-- Get some names as candidates, then look for them.
	
		-- grab some distant variables step by step so we don't confuse the poor lua interpreter
		local sNote = LiveRoster.Toons[iAlt.Name].Note;
		
		
		local sMainName, sAlternateMainName = LiveRoster.IsAlt(sNote)
		--Make common functions local

		sMainName = myQuickUpper(sMainName);
		--make the functions local to be quicker.
		
		-- Find Mains with table. Main's short names were stored as they were found.
		if self.ShortNames[sMainName] then
			--Matched_count = Matched_count + 1;
			myMain = self.ShortNames[sMainName];
			if not myMain.Alts then myMain.Alts = { } end
			myQuickInsert(myMain.Alts, iAlt)
			-- Hook the main and alt from the main list together with pointers.
			iAlt.Main = myMain;
			--Now if you look this character up as a player, the main will be returned, as intended.
			LiveRoster.Players[iAlt.Name] = LiveRoster.Players[myMain.Name]
            
            -- Pack into LRSNAPSHOT as an alt with a main. Only write to snapshot if we're in main guild.
            if not bInAltGuild then 
            LRSNAPSHOT.Toons[iAlt.Name].Main = myMain.Name
        
            end

			iAlt.IsMain = 0;
			iAlt.ErrorStatus = 0;
			iAlt.DaysInGuild = myMain.DaysInGuild;
			-- Queue alt for promotion if main needs it and main is equal or higher rank than alt.
			if myMain.NeedsPromotion > 0 and myMain.RankIndex <= iAlt.RankIndex then
				iAlt.NeedsPromotion = 1;
				LRAP = LRAP +1;
			end
			--Queue alt for promotion if it's less than main rank, and promotable by player, but don't mess with guild master or hand rank.
			if myMain.RankIndex < iAlt.RankIndex and myMain.RankIndex > 1 then
				iAlt.NeedsPromotion = 1;
				LRAP = LRAP +1;
			end
			
				-- OPTIONAL: MAYBE ADD LOWEST DAYS OFFLINE COUNTER AGAIN IF WANTED, OBSOLETE FOR NOW
				-- OPTIONAL: ALSO ADD IN SUPPORT FOR ALTOHOLICEST.
		end
			

	
	end -- alt sorting
	

	LiveRoster.ShortNames = nil;	

	for i=1, #GuildRosterContainer.buttons do
		_G["GuildRosterContainerButton"..i]:SetScript("OnEnter", ShowRosterTooltip);
		_G["GuildRosterContainerButton"..i]:SetScript("OnLeave", HideRosterTooltip);
		--_G["GuildRosterContainerButton"..i]:SetScript("OnDoubleClick", LiveRoster_NameCopy);
		_G["GuildRosterContainerButton"..i]:HookScript("OnClick", LiveRoster_NameCopy);
	end
	--We left a few hanging things that should be cleaned up so...
	LiveRoster.Loaded = 1;

    if LiveRoster.ExtensionSelection then
		local myIndex = LiveRoster.Roster.NameIndex[LiveRoster.ExtensionSelection];
		
		if myIndex and myIndex > 0 then
			SetGuildRosterSelection(myIndex);
		else
			LRE("myIndex from NameIndex < 1. Can't select a guild member!");
		end
	end
	

	GuildRoster();
	GuildRoster_Update();	  
	 LR_DIRTY = nil; -- Roster is squeaky clean. 
 end 



--[[


       d88P   888     8888888888b. 8888888b.        d8888888888888888888888888 
      d88P    888     888888   Y88b888  "Y88b      d88888    888    888        
     d88P     888     888888    888888    888     d88P888    888    888        
    d88P      888     888888   d88P888    888    d88P 888    888    8888888    
   d88P       888     8888888888P" 888    888   d88P  888    888    888        
  d88P        888     888888       888    888  d88P   888    888    888        
 d88P         Y88b. .d88P888       888  .d88P d8888888888    888    888        
d88P           "Y88888P" 888       8888888P" d88P     888    888    8888888888 
                                                                               
                                                                               
                                                                               
8888888b.  .d88888b.  .d8888b.8888888888888888888888888888b.  
888   Y88bd88P" "Y88bd88P  Y88b   888    888       888   Y88b 
888    888888     888Y88b.        888    888       888    888 
888   d88P888     888 "Y888b.     888    8888888   888   d88P 
8888888P" 888     888    "Y88b.   888    888       8888888P"  
888 T88b  888     888      "888   888    888       888 T88b   
888  T88b Y88b. .d88PY88b  d88P   888    888       888  T88b  
888   T88b "Y88888P"  "Y8888P"    888    8888888888888   T88b 
                                                              

]]--


 --****************************************************************************************
 --********************************************************************************
 --*************************************************************************
 --*****************************************************************
 --************************************************************
 --************************************************************
 --****************************************************
 --***********************************************
 --****************
  
function LRMEM()



		UpdateAddOnMemoryUsage();

		GetAddOnMemoryUsage("TC LiveRoster");
		local sAddonName, _ = GetAddOnInfo("LiveRoster");
		local myMem = GetAddOnMemoryUsage(sAddonName);
		LRE(sAddonName.." memory useage: "..tostring(myMem).. ". A difference of "..myMem - LRLASTMEM.."kb." );
		LRLASTMEM = myMem;
		--LRE("Orphan Count: ".. #LiveRoster.Roster-Matched_count.." Mains: "..#LiveRoster.Roster.Mains.." Total: "..Player_count);
		--LRE("Reused toon slots: "..LiveRoster_Reused_Slots);
		--Matched_count = 0;

	  

LRE("Garbage: ".. collectgarbage("count"));

collectgarbage("collect");

end
  
  
function LiveRoster_NameCopy(self, button)

--This is an OnClick handler.  should get ismodified...
	if ( IsModifiedClick() ) then
  
		StaticPopupDialogs["LIVEROSTER_NAMECOPY"] = {
			text = "Name Copy",
			button1 = "Done",
			OnShow = function (self, data)
							self.editBox:SetText(strmatch(GuildMemberDetailName:GetText(), "(.+)-.+"))
							self.editBox:HighlightText();
							self.editBox:SetScript("OnKeyUp", function(self, myKey)
							--SendChatMessage("Key pressed!");
							if myKey == "ENTER" or myKey == "ESCAPE" then
								self:OnAccept();
							end
						
						end)
					end,
			OnAccept = function (self, data, data2)
						
						-- do whatever you want with it
					end,
			OnKeyDown = function(myKey)
						
							if myKey == "ENTER" or myKey == "ESCAPE" then
								self:OnAccept();
							end
						end,
							
							
			hasEditBox = true,
			enterClicksFirstButton = true,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
		}

		StaticPopup_Show ("LIVEROSTER_NAMECOPY");

	end
end

function LiveRoster_OptionsOK()

	LRE("Options OK!", 1);

end

function LiveRoster_OptionsCancel()

	LRE("Options Cancel!", 1);

end

function LiveRoster_OptionsRefresh()

	LRE("Options Refresh!", 1)

end

function LiveRoster_OptionsDefault()

	LRE("Options Default!", 1)

end

function LiveRosterOptions_OnLoad(panel)


        -- Set the name for the Category for the Panel
        --
        panel.name = "Live Roster";

        -- When the player clicks okay, run this function.
        --
        panel.okay = function (self) LiveRoster_OptionsOK(); end;

        -- When the player clicks cancel, run this function.
        --
        panel.cancel = function (self)  LiveRoster_OptionsCancel();  end;

		panel.refresh = function (self)  LiveRoster_OptionsRefresh();  end;
		
		panel.default = function (self)  LiveRoster_OptionsDefault();  end;
		
        -- Add the panel to the Interface Options
        --
        InterfaceOptions_AddCategory(panel);
    

end
  
  
