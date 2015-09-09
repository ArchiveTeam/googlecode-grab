dofile("urlcode.lua")
dofile("table_show.lua")

local url_count = 0
local tries = 0
local added = 0
local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')

local downloaded = {}
local addedtolist = {}

local status_code = nil

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
    if status_code ~= 404 and ((string.match(url, "https?://code%.google%.com/p/"..itemvalue) and not string.match(url, "https?://code%.google%.com/p/"..itemvalue.."[0-9a-zA-Z%-]")) or string.match(url, itemvalue.."%.googlecode%.com") or string.match(url, "https?://code%.google%.com/[^/]+/p/"..itemvalue) or html == 0) and not (string.match(url, "google%.com/accounts/ServiceLogin%?") or string.match(url, "https?://accounts%.google%.com/ServiceLogin%?") or (string.match(url, "%?r=") and not string.match(url, "detail%?r=")) or string.match(url, "/%?repo=[^&]+&r=")) then
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
  
  local function check(url)
    if (downloaded[string.match(url, "https?://([^#]+)")] ~= true and addedtolist[string.match(url, "https?://([^#]+)")] ~= true) and (string.match(url, "https?://code%.google%.com") or string.match(url, "https?://[^%.]+%.googlecode%.com") or string.match(url, "https?://[^%.]+%.[^%.]+%.googlecode%.com")) and not (string.match(url, "https?://code%.google%.com/archive/p/") or (string.match(url, "%?r=") and not string.match(url, "detail%?r=")) or string.match(url, "%?repo=[^&]+&r=") or string.match(url, "google%.com/accounts/ServiceLogin%?") or string.match(url, "https?://accounts%.google%.com/ServiceLogin%?") or string.match(url, ">") or string.match(url, "%%3E")) then
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
    if string.match(url, "/"..itemvalue) and not string.match(url, "/"..itemvalue.."[0-9a-zA-Z%-]") then
      html = read_file(file)
      for newurl in string.gmatch(html, 'href=("[^"]+)"') do
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
      for newurl in string.gmatch(html, "'(https?://[^']+)'") do
        if (string.match(newurl, "https?://code%.google%.com/p/"..itemvalue) and not string.match(newurl, "https?://code%.google%.com/p/"..itemvalue.."[0-9a-zA-Z%-]")) or string.match(newurl, itemvalue.."%.googlecode%.com") or string.match(newurl, "code%.google%.com/[^/]+/p/"..itemvalue) then
          check(newurl)
        end
      end
      for newurl in string.gmatch(html, '"%.%./%.%.(/[^"]+)"') do
        if string.match(newurl, "/"..itemvalue) and not string.match(newurl, "/"..itemvalue.."[0-9a-zA-Z%-]") then
          check(string.match(url, "(https?://[^/]+/[^/]+)/")..newurl)
        end
      end
      for newurl in string.gmatch(html, '"(/[^"]+)"') do
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
