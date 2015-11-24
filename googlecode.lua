dofile("urlcode.lua")
dofile("table_show.lua")
JSON = (loadfile "JSON.lua")()

local url_count = 0
local tries = 0
local added = 0
local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')

local downloaded = {}
local addedtolist = {}

local status_code = nil

load_json_file = function(file)
  if file then
    return JSON:decode(file)
  else
    return nil
  end
end

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

revisioncheck = function(url)
  local repo = nil
  if string.match(url, "%?repo=[a-z0-9A-Z%-]+") or string.match(url, "&repo=[a-z0-9A-Z%-]+") then
    repo = string.match(url, "repo=([a-z0-9A-Z%-]+)")
  end
  local revision = string.match(url, "[^a-z0-9A-Z%-]r=([a-z0-9A-Z%-]+)")
  local svnrevision = "nosvnrevision"
  if repo ~= nil then
    svnrevision = string.match(url, "[^a-z0-9A-Z%-]spec=svn%.[^%.]+%.([a-z0-9A-Z%-]+)")
  elseif repo == nil then
    svnrevision = string.match(url, "[^a-z0-9A-Z%-]spec=svn([a-z0-9A-Z%-]+)")
  end
  if svnrevision == revision then
    return true
  else
    return false
  end
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]
  local itemvalue = string.gsub(item_value, "%-", "%%-")
  
  if downloaded[string.match(url, "https?://([^#]+)")] == true or addedtolist[string.match(url, "https?://([^#]+)")] == true then
    return false
  end
  
  if item_type == "project" and (downloaded[string.match(url, "https?://([^#]+)")] ~= true or addedtolist[string.match(url, "https?://([^#]+)")] ~= true) then
    -- or (string.match(url, "%?r=") and not string.match(url, "detail%?r=")) or string.match(url, "/%?repo=[^&]+&r=")
    if status_code ~= 404 and ((string.match(url, "https?://code%.google%.com/p/"..itemvalue) and not string.match(url, "https?://code%.google%.com/p/"..itemvalue.."[0-9a-zA-Z%-]")) or string.match(url, itemvalue.."%.googlecode%.com") or string.match(url, "https?://code%.google%.com/[^/]+/p/"..itemvalue) or html == 0) and not (string.match(url, "google%.com/accounts/ServiceLogin%?") or string.match(url, "https?://accounts%.google%.com/ServiceLogin%?")) then
      if string.match(url, "[^a-z0-9A-Z%-]spec=svn") and string.match(url, "[^a-z0-9A-Z%-]r=") then
        if revisioncheck(url) == true then
          addedtolist[string.match(url, "https?://([^#]+)")] = true
          added = added + 1
          return true
        end
      else
        addedtolist[string.match(url, "https?://([^#]+)")] = true
        added = added + 1
        return true
      end
    else
      return false
    end
  end
end


wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil
  local itemvalue = string.gsub(item_value, "%-", "%%-")
  
  local function check(urla)
    local url = string.match(urla, "^([^#]+)")
      -- or (string.match(url, "%?r=") and not string.match(url, "detail%?r=")) or string.match(url, "%?repo=[^&]+&r=")
    if (downloaded[string.match(url, "https?://([^#]+)")] ~= true and addedtolist[string.match(url, "https?://([^#]+)")] ~= true) and (string.match(url, "https?://code%.google%.com") or string.match(url, "https?://[^%.]+%.googlecode%.com") or string.match(url, "https?://[^%.]+%.[^%.]+%.googlecode%.com")) and not (string.match(url, "https?://code%.google%.com/archive/p/") or string.match(url, "google%.com/accounts/ServiceLogin%?") or string.match(url, "https?://accounts%.google%.com/ServiceLogin%?") or string.match(url, ">") or string.match(url, "%%3E")) then
      if string.match(url, "&amp;") then
        check(string.gsub(url, "&amp;", "&"))
        addedtolist[string.match(url, "https?://([^#]+)")] = true
      elseif string.match(url, "[^a-z0-9A-Z%-]spec=svn") and string.match(url, "[^a-z0-9A-Z%-]r=") then
        if revisioncheck(url) == true then
          table.insert(urls, { url=url })
          addedtolist[string.match(url, "https?://([^#]+)")] = true
          added = added + 1
        end
      else
        table.insert(urls, { url=url })
        addedtolist[string.match(url, "https?://([^#]+)")] = true
        added = added + 1
      end
    end
  end
  
  if item_type == "project" and status_code ~= 404 then
    local jsonfiles = {}
    if string.match(url, "/"..itemvalue) and not string.match(url, "/"..itemvalue.."[0-9a-zA-Z%-]") then
      html = read_file(file)
      for newurl in string.gmatch(html, 'href=("[^"]+)') do
        if string.match(newurl, '"https?://') then
          if (string.match(string.match(newurl, '"(.+)'), "https?://code%.google%.com/p/"..itemvalue) and not string.match(string.match(newurl, '"(.+)'), "https?://code%.google%.com/p/"..itemvalue.."[0-9a-zA-Z%-]")) or string.match(string.match(newurl, '"(.+)'), itemvalue.."%.googlecode%.com") or string.match(string.match(newurl, '"(.+)'), "https?://code%.google%.com/[^/]+/p/"..itemvalue) then
            check(string.match(newurl, '"(.+)'))
          end
        elseif not (string.match(newurl, '"/') or string.match(newurl, '"%.%./%.%.')) then
          check(string.match(string.match(url, "(https?://[^%?]+)"), "(https?://.+/)")..string.match(newurl, '"(.+)'))
        end
      end
--      for newurl in string.gmatch(html, '"(https?://[^"]+)"') do
--        if (string.match(newurl, "https?://code%.google%.com/p/"..itemvalue) and not string.match(newurl, "https?://code%.google%.com/p/"..itemvalue.."[0-9a-zA-Z%-]")) or string.match(newurl, itemvalue.."%.googlecode%.com") then
--          check(newurl)
--        end
--      end
      for newurl in string.gmatch(html, "'(https?://[^']+)") do
        if (string.match(newurl, "https?://code%.google%.com/p/"..itemvalue) and not string.match(newurl, "https?://code%.google%.com/p/"..itemvalue.."[0-9a-zA-Z%-]")) or string.match(newurl, itemvalue.."%.googlecode%.com") or string.match(newurl, "code%.google%.com/[^/]+/p/"..itemvalue) then
          check(newurl)
        end
      end
--      for branch in string.gmatch(string.match(html, '<select%s+id="branch_select"[^>]+>(.-)</select>'), 'value="([^"]+)"') do
--        if string.match(url, "[^a-z0-9A-Z%-]name=") then
--          check(string.gsub(url, "name=[^a-z0-9A-Z%.%-_]+", "name="..branch)
--        else
--          check(string.match(string.match(url, "(https?://[^%?]+)"), "(https?://[^#]+)").."?name="..value)
--        end
--      end
      for select in string.gmatch(html, '(<select[^>]+>.-</select>)') do
        local selectname = string.match(string.match(select, "<select([^>]+)>"), 'name="([^"]+)"')
        for value in string.gmatch(string.match(select, '<select[^>]+>(.-)</select>'), 'value="([^"]+)"') do
          if string.match(url, "[^0-9a-zA-Z%-%._]"..selectname.."=") then
            check(string.gsub(url, selectname.."=[0-9a-zA-Z%.%-_]+", selectname.."="..value))
          else
            check(string.match(string.match(url, "(https?://[^%?]+)"), "(https?://[^#]+)").."?"..selectname.."="..value)
          end
        end
      end
      if string.match(url, "/dirfeed%?c=") then
        local json = html
        jsonlua = load_json_file(json)
        local revision = string.match(url, "[^0-9a-zA-Z]r=([0-9a-zA-Z%-_]+)")
        local newfolders = { "jsonlua" }
        local firstdir = true
        while true do
          if #newfolders == 0 then
            break
          end
          local newsubdirs = newfolders
          newfolders = {}
          for _, subdir in pairs(newsubdirs) do
            local loadingstring = nil
            if string.gsub(string.match(subdir, "^[^%.]+%.?(.*)"), "%.", '"]["') == "" then
              loadingstring = "return "..string.match(subdir, "^([^%.]+)")
            else
              loadingstring = "return "..string.match(subdir, "^([^%.]+)")..string.gsub('["'..string.gsub(string.match(subdir, "^[^%.]+%.?(.*)"), "%.?subdirs%.", '"]["subdirs"]["'), '%[""%]', "")..'"]["subdirs"]'
            end
            if assert(loadstring(loadingstring))() then
              for a, b in pairs(assert(loadstring(loadingstring))()) do
                if firstdir == true then
                  table.insert(jsonfiles, subdir.."."..a)
                  table.insert(newfolders, subdir.."."..a)
                  firstdir = false
                else
                  table.insert(jsonfiles, subdir..".subdirs."..a)
                  table.insert(newfolders, subdir..".subdirs."..a)
                end
              end
            end
          end
        end
        for _, subdir in pairs(jsonfiles) do
          if string.match(subdir, "jsonlua%..-%.subdirs%.") then
            local localc = ""
            if string.match(url, "/dirfeed%?c=(.+)&p=") then
              localc = string.gsub(string.gsub(string.match(url, "/dirfeed%?c=(.-)&p="), "/", "%%2F").."%2F", "%%2F%%2F", "%%2F")
            end
            check("https://code.google.com/p/"..item_value.."/source/dirfeed?c="..localc.."&p="..string.gsub(string.gsub(string.match(subdir, "jsonlua%.(.+)"), "%.subdirs%.", "%%252F"), "/", "%%252F").."&l=2&fp=1&sp=1&r="..revision)
            check("https://code.google.com/p/"..item_value..string.gsub("/source/browse/"..string.gsub(localc, "%%2F", "/")..'/'..string.gsub(string.match(subdir, "jsonlua%.(.+)"), "%.subdirs%.", "/").."/?r="..revision, "//", "/"))
            local loadingstring = "return "..string.match(subdir, "^([^%.]+)")..string.gsub('["'..string.gsub(string.match(subdir, "^[^%.]+%.?(.*)"), "%.?subdirs%.", '"]["subdirs"]["'), '%[""%]', "")..'"]["filePage"]'
            if assert(loadstring(loadingstring))() then
              for a, b in pairs(assert(loadstring(loadingstring..'["files"]'))()) do
                if string.match(url, "[^a-z0-9A-Z%-_]r=[0-9a-zA-Z%-_]+") then
                  check("https://code.google.com/p/"..item_value..string.gsub("/source/browse/"..string.gsub(localc, "%%2F", "/")..'/'..string.gsub(string.match(subdir, "jsonlua%.(.+)"), "%.subdirs%.", "/").."/"..a.."?r="..string.match(url, "[^a-z0-9A-Z%-_]r=([0-9a-zA-Z%-_]+)"), "//", "/"))
                else
                  check("https://code.google.com/p/"..item_value..string.gsub("/source/browse/"..string.gsub(localc, "%%2F", "/")..'/'..string.gsub(string.match(subdir, "jsonlua%.(.+)"), "%.subdirs%.", "/").."/"..a, "//", "/"))
                end
              end
            end
          end
        end
      end
      for jsonline in string.gmatch(html, "_init%(([^\n]+)") do
        local json = string.match(jsonline, "(.+)%);$")
        jsonlua = load_json_file(json)
        local revision = string.match(html, "_setViewedRevision%('([^']+)'%)")
        local newfolders = { "jsonlua" }
        while true do
          if #newfolders == 0 then
            break
          end
          local newsubdirs = newfolders
          newfolders = {}
          for _, subdir in pairs(newsubdirs) do
            local loadingstring = nil
            if string.gsub(string.match(subdir, "^[^%.]+%.?(.*)"), "%.", '"]["') == "" then
              loadingstring = "return "..string.match(subdir, "^([^%.]+)")..'["subdirs"]'
            else
              loadingstring = "return "..string.match(subdir, "^([^%.]+)")..string.gsub('["'..string.gsub(string.match(subdir, "^[^%.]+%.?(.*)"), "%.?subdirs%.", '"]["subdirs"]["'), '%[""%]', "")..'"]["subdirs"]'
            end
            if assert(loadstring(loadingstring))() then
              for a, b in pairs(assert(loadstring(loadingstring))()) do
                table.insert(jsonfiles, subdir..".subdirs."..a)
                table.insert(newfolders, subdir..".subdirs."..a)
              end
            end
          end
        end
        for _, subdir in pairs(jsonfiles) do
          if string.match(subdir, "jsonlua%.subdirs%.[^%.]+%.subdirs%.") then
            local localc = ""
            if string.match(url, "/source/browse/[^#%?%%]+") then
              localc = string.gsub(string.gsub(string.match(url, "/source/browse/([^#%?%%]+)"), "/", "%%2F").."%2F", "%%2F%%2F", "%%2F")
            end
            check("https://code.google.com/p/"..item_value.."/source/dirfeed?c="..localc.."&p="..string.gsub(string.match(subdir, "jsonlua%.subdirs%.[^%.]+%.subdirs%.(.+)"), "%.subdirs%.", "%%252F").."&l=2&fp=1&sp=1&r="..revision)
            check("https://code.google.com/p/"..item_value..string.gsub("/source/browse/"..string.gsub(localc, "%%2F", "/")..'/'..string.gsub(string.match(subdir, "jsonlua%.subdirs%.[^%.]+%.subdirs%.(.+)"), "%.subdirs%.", "/").."/?r="..revision, "//", "/"))
            local loadingstring = "return "..string.match(subdir, "^([^%.]+)")..string.gsub('["'..string.gsub(string.match(subdir, "^[^%.]+%.?(.*)"), "%.?subdirs%.", '"]["subdirs"]["'), '%[""%]', "")..'"]["filePage"]'
            if assert(loadstring(loadingstring))() then
              for a, b in pairs(assert(loadstring(loadingstring..'["files"]'))()) do
                if string.match(url, "[^a-z0-9A-Z%-_]r=[0-9a-zA-Z%-_]+") then
                  check("https://code.google.com/p/"..item_value..string.gsub("/source/browse/"..string.gsub(localc, "%%2F", "/")..'/'..string.gsub(string.match(subdir, "jsonlua%.subdirs%.[^%.]+%.subdirs%.(.+)"), "%.subdirs%.", "/").."/"..a.."?r="..string.match(url, "[^a-z0-9A-Z%-_]r=([0-9a-zA-Z%-_]+)"), "//", "/"))
                else
                  check("https://code.google.com/p/"..item_value..string.gsub("/source/browse/"..string.gsub(localc, "%%2F", "/")..'/'..string.gsub(string.match(subdir, "jsonlua%.subdirs%.[^%.]+%.subdirs%.(.+)"), "%.subdirs%.", "/").."/"..a, "//", "/"))
                end
              end
            end
          end
        end
      end
--      for newurl in string.gmatch(html, '"([^"]+)":%s+%[') do
--        if string.match(url, '%?r=[a-z0-9A-Z%-]+#svn') then
--          check(string.match(url, "(https?://.+)/%?r=[a-z0-9A-Z%-]+#svn")..string.gsub(string.match(url, "https?://.+%?r=[a-z0-9A-Z%-]+#svn(.+)"), "%2F", "/").."/"..newurl..string.match(url, "(%?r=[a-z0-9A-Z%-]+)#svn"))
--        elseif string.match(url, "#svn") then
--          check(string.gsub(url, "/#svn", "").."/"..newurl)
--        end
--      end
      for newurl in string.gmatch(html, '"%.%./%.%.(/[^"]+)') do
        if string.match(newurl, "/"..itemvalue) and not string.match(newurl, "/"..itemvalue.."[0-9a-zA-Z%-]") then
          check(string.match(url, "(https?://[^/]+/[^/]+)/")..newurl)
        end
      end
      for newurl in string.gmatch(html, '"(/[^"]+)') do
        if string.match(newurl, "//") and ((string.match(newurl, "code%.google%.com/p/"..itemvalue) and not string.match(newurl, "code%.google%.com/p/"..itemvalue.."[0-9a-zA-Z%-]")) or string.match(newurl, itemvalue.."%.googlecode%.com") or string.match(newurl, "code%.google%.com/[^/]+/p/"..itemvalue)) then
          check(string.gsub(newurl, "//", "http://"))
        elseif string.match(newurl, "/p/"..itemvalue) and not string.match(newurl, "/p/"..itemvalue.."[0-9a-zA-Z%-]") then
          check("https://code.google.com"..newurl)
        end
      end
      for newurl in string.gmatch(url, "(https?://.+)/") do
        if ((string.match(newurl, "https?://code%.google%.com/p/"..itemvalue) or string.match(newurl, itemvalue.."%.googlecode%.com") or string.match(newurl, "https?://code%.google%.com/[^/]+/p/"..itemvalue)) and not string.match(newurl, "https?://code%.google%.com/p/"..itemvalue.."[0-9a-zA-Z%-]")) then
          check(newurl)
        end
      end
      for newurl in string.gmatch(url, "(https?://[^%?]+)%?") do
        check(newurl)
      end
      if string.match(url, "https://code.google.com/p/"..itemvalue.."/issues/detail%?id=[0-9]+") then
        local id = string.match(url, "https://code.google.com/p/"..itemvalue.."/issues/detail%?id=([0-9]+)")
        check("https://code.google.com/p/"..item_value.."/issues/detail?id="..id.."&can=1")
        check("https://code.google.com/p/"..item_value.."/issues/detail?id="..id)
        check("https://code.google.com/p/"..item_value.."/issues/peek?id="..id.."&can=1")
        check("https://code.google.com/p/"..item_value.."/issues/peek?id="..id)
      end
    end
  end

  return urls
end
  

wget.callbacks.httploop_result = function(url, err, http_stat)
  -- NEW for 2014: Slightly more verbose messages because people keep
  -- complaining that it's not moving or not working
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count.."/"..added.." = "..status_code.." "..url["url"]..".  \n")
--  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. ".  \n")
  io.stdout:flush()

  -- test for string.gsub()
  if string.gsub("%2F%2F", "%%2F%%2F", "%%2F") ~= "%2F" then
    io.stdout:write("For test 1 string.gsub gave "..string.gsub("%2F%2F", "%%2F%%2F", "%%2F").." for you, please let ArchiveTeam know!  \n")
    io.stdout:flush()
    return wget.actions.ABORT
  end
  if string.gsub('[""]', '%[""%]', "") ~= "" then
    io.stdout:write("For test 2 string.gsub gave "..string.gsub('[""]', '%[""%]', "").." for you, please let ArchiveTeam know!  \n")
    io.stdout:flush()
    return wget.actions.ABORT
  end

  if downloaded[url["url"]] == true then
    return wget.actions.EXIT
  end

  if status_code == 404 or status_code == 403 or status_code == 400 then
    if addedtolist[string.match(url["url"], "https?://([^#]+)")] ~= true then
      added = added + 1
    end
  end

  if (status_code >= 200 and status_code <= 399) then
    downloaded[string.match(url["url"], "https?://([^#]+)")] = true
    if addedtolist[string.match(url["url"], "https?://([^#]+)")] ~= true then
      added = added + 1
    end
  end
  
  if status_code >= 500 or
    (status_code >= 401 and status_code ~= 404 and status_code ~= 403) then

    io.stdout:write("\nServer returned "..http_stat.statcode..". Sleeping.\n")
    io.stdout:flush()

    os.execute("sleep 1")

    tries = tries + 1

    if tries >= 15 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      return wget.actions.ABORT
    else
      return wget.actions.CONTINUE
    end
  elseif status_code == 0 then

    io.stdout:write("\nServer returned "..http_stat.statcode..". Sleeping.\n")
    io.stdout:flush()

    os.execute("sleep 10")
    
    tries = tries + 1

    if tries >= 10 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      return wget.actions.ABORT
    else
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  -- We're okay; sleep a bit (if we have to) and continue
  -- local sleep_time = 0.5 * (math.random(75, 100) / 100.0)
  local sleep_time = 0

  --  if string.match(url["host"], "cdn") or string.match(url["host"], "media") then
  --    -- We should be able to go fast on images since that's what a web browser does
  --    sleep_time = 0
  --  end

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end
