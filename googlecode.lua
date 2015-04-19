dofile("urlcode.lua")
dofile("table_show.lua")

local url_count = 0
local tries = 0
local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')

local downloaded = {}
local addedtolist = {}

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

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]
  local itemvalue = string.gsub(item_value, "%-", "%%-")
  
  if downloaded[url] == true or addedtolist[url] == true then
    return false
  end
  
  if item_type == "project" and (downloaded[url] ~= true or addedtolist[url] ~= true) then
    if (string.match(url, "/"..itemvalue) and not string.match(url, "/"..itemvalue.."[0-9a-zA-Z%-]")) or string.match(url, itemvalue.."%.googlecode%.com") or html == 0 then
      addedtolist[url] = true
      return true
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
    if (downloaded[url] ~= true and addedtolist[url] ~= true) then
      table.insert(urls, { url=url })
      addedtolist[url] = true
    end
  end
  
  if item_type == "project" then
    if string.match(url, "/"..itemvalue) and not string.match(url, "/"..itemvalue.."[0-9a-zA-Z%-]") then
      html = read_file(file)
      for newurl in string.gmatch(html, '"(https?://[^"]+)"') do
        if (string.match(newurl, "/"..itemvalue) and not string.match(newurl, "/"..itemvalue.."[0-9a-zA-Z%-]")) or string.match(newurl, itemvalue.."%.googlecode%.com") then
          check(newurl)
        end
      end
      for newurl in string.gmatch(html, '"(/[^"]+)"') do
        if string.match(newurl, "//") and ((string.match(newurl, "/"..itemvalue) and not string.match(newurl, "/"..itemvalue.."[0-9a-zA-Z%-]")) or string.match(newurl, itemvalue.."%.googlecode%.com")) then
          check(string.gsub(newurl, "//", "http://")
        elseif (string.match(newurl, "/"..itemvalue) and not string.match(newurl, "/"..itemvalue.."[0-9a-zA-Z%-]")) or string.match(newurl, itemvalue.."%.googlecode%.com") then
          check("https://code.google.com"..newurl)
        end
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
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. ".  \n")
  io.stdout:flush()

  if (status_code >= 200 and status_code <= 399) then
    if string.match(url.url, "https://") then
      local newurl = string.gsub(url.url, "https://", "http://")
      downloaded[newurl] = true
    else
      downloaded[url.url] = true
    end
  end
  
  if status_code >= 500 or
    (status_code >= 400 and status_code ~= 404 and status_code ~= 403) then

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
