local _G = _G or getfenv(0)
local addon,NAME = {},"LanguageFilter"
addon.msg_buffer, addon.sorted_buffer = {}, {}
addon.hooks = {}
local char_ranges = {
  ["_allow"] = {["lo"]=0,["hi"]=127} -- en ascii
}
local PATTERN_CHAR, PATTERN_WORD = "[%z\1-\127\194-\244][\128-\191]*", "%S+"
LanguageFilterDBPC = LanguageFilterDBPC or {
  ["single_word_allow"] = false,
  ["show_link"] = true,
  ["buffer_size"] = 100
}
local Print, WordCount, CharCount, MsgTimeStamp, StrTrim, DoHooks
-- Event handling
local f = CreateFrame("Frame")
f.OnEvent = function()
  return addon[event]~=nil and addon[event](event,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11)
end
f:SetScript("OnEvent",f.OnEvent)
f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
addon.VARIABLES_LOADED = function(event)
  addon.db = LanguageFilterDBPC
end
addon.PLAYER_LOGIN = function(event)
  DoHooks()
end
-- Hooks
DoHooks = function()
  addon.hooks.ChatFrame_OnHyperlinkShow = ChatFrame_OnHyperlinkShow
  addon.ChatFrame_OnHyperlinkShow = function(link, text, button)
    local link = link or arg1
    local text = text or arg2
    local button = button or arg3
    if string.sub(link,1,4) == "lnf:" then
      local key = string.sub(link,5,-1)
      if addon.msg_buffer[key] then
        this:AddMessage(addon.msg_buffer[key],0.4,0.4,0.4,nil,true)
      else
        Print("<old msg removed due to buffer limit>")
      end
      return
    end
    addon.hooks.ChatFrame_OnHyperlinkShow(link, text, button)
  end
  ChatFrame_OnHyperlinkShow = addon.ChatFrame_OnHyperlinkShow
  for i=1,NUM_CHAT_WINDOWS do
    local chatFrameName = "ChatFrame"..i
    local chatFrame = getglobal(chatFrameName)
    if not (chatFrame.isHooked or i == 2) then
      addon.hooks[chatFrameName] = {}
      addon[chatFrameName] = {}
      addon.hooks[chatFrameName].AddMessage = chatFrame.AddMessage
      addon[chatFrameName].AddMessage = function(chatFrame,msg,r,g,b,id,skip)
        local count, block_count = CharCount(msg)
        local word_count = WordCount(msg)
        if block_count > 0 and not ( skip or (word_count == 1 and addon.db.single_word_allow) ) then
          if addon.db.show_link then
            addon.hooks[chatFrameName].AddMessage(chatFrame,MsgTimeStamp(msg),r,g,b,id)
          end
        else
          addon.hooks[chatFrameName].AddMessage(chatFrame,msg,r,g,b,id)
        end
      end
      chatFrame.AddMessage = addon[chatFrameName].AddMessage
      chatFrame.isHooked = true
    end
  end
end
-- Utility functions
Print = function(msg)
  if not DEFAULT_CHAT_FRAME:IsVisible() then
    FCF_SelectDockFrame(DEFAULT_CHAT_FRAME)
  end
  local out = "|cff0000ffLangFilter:|r"..tostring(msg)
  DEFAULT_CHAT_FRAME:AddMessage(out)
end
StrTrim = function(str)
  return (string.gsub(str,"^%s*(.-)%s*$", "%1"))
end
WordCount = function(msg)
  if not msg or (StrTrim(msg) == "") then
    return 0
  end
  local _,num = string.gsub(msg,"%S+","")
  return num
end
CharCount = function(msg)
  local count,block_count = 0,0
  string.gsub(msg,PATTERN_CHAR,
    function(c)
      count = count + 1
      local byteArray = {string.byte(c,1,-1)}
      if tonumber(byteArray[1])>char_ranges._allow.hi 
        or tonumber(byteArray[1])<char_ranges._allow.lo
        or tonumber(byteArray[2]) then
        block_count = block_count + 1
      end
      byteArray = {}
    end)
  return count, block_count
end
MsgTimeStamp = function(msg)
  local hour, minute = GetGameTime()
  local seconds = math.mod(time(), 24 * 60 * 60)
  local hours = math.floor(seconds / (60 * 60))
  seconds = seconds - hours * 60 * 60
  local minutes = math.floor(seconds / 60)
  seconds = seconds - minutes * 60;
  local timestamp = format("%02d:%02d:%02d", hour, minutes, seconds)
  if table.getn(addon.sorted_buffer) == addon.db.buffer_size then
    local key = table.remove(addon.sorted_buffer,1)
    addon.msg_buffer[key] = nil
  end
  local key = timestamp..":"..tostring(debugprofilestop())
  addon.msg_buffer[key]=msg
  table.insert(addon.sorted_buffer,key)
  local blocked = "|cffff0000|Hlnf:"..key.."|h[msg blocked@"..timestamp.."]|h|r"
  return blocked
end
-- Make us accessible for in-game debug
_G[NAME] = addon

--[[
Notes:
http://www.utf8-chartable.de/unicode-utf8-table.pl
]]