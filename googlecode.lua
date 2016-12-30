dofile("urlcode.lua")
dofile("table_show.lua")
JSON = (loadfile "JSON.lua")()

local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')
local item_dir = os.getenv('item_dir')

local items = {}

local url_count = 0
local tries = 0
local downloaded = {}
local addedtolist = {}
local abortgrab = false

for ignore in io.open("ignore-list", "r"):lines() do
  downloaded[ignore] = true
end

for item in string.gmatch(item_value, "([^,]+)") do
  items[item] = true

  
end

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

allowed = function(url)
  if string.match(url, "'+")
     or string.match(url, "[<>\\]")
     or string.match(url, "//$") then
    return false
  end

  if item_type == "archive" then
    if string.match(url, "^https?://code%.google%.com/p/") then
      return false
    end
    for s in string.gmatch(url, "([0-9a-z%-]+)") do
      if s == item_value then
        return true
      end
    end
  end

  return false
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]

  if (downloaded[url] ~= true and addedtolist[url] ~= true)
     and (allowed(url) or html == 0) then
    addedtolist[url] = true
    return true
  else
    return false
  end
end

wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil

  downloaded[url] = true
  
  local function check(urla)
    local origurl = url
    local url = string.match(urla, "^([^#]+)")
    if (downloaded[url] ~= true and addedtolist[url] ~= true)
       and allowed(url) then
      table.insert(urls, { url=string.gsub(url, "&amp;", "&") })
      addedtolist[url] = true
      addedtolist[string.gsub(url, "&amp;", "&")] = true
    end
  end

  local function checknewurl(newurl)
    if string.match(newurl, "^https?:////") then
      check(string.gsub(newurl, ":////", "://"))
    elseif string.match(newurl, "^https?://") then
      check(newurl)
    elseif string.match(newurl, "^https?:\\/\\?/") then
      check(string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^\\/\\/") then
      check(string.match(url, "^(https?:)")..string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^//") then
      check(string.match(url, "^(https?:)")..newurl)
    elseif string.match(newurl, "^\\/") then
      check(string.match(url, "^(https?://[^/]+)")..string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^/") then
      check(string.match(url, "^(https?://[^/]+)")..newurl)
    end
  end

  local function checknewshorturl(newurl)
    if string.match(newurl, "^%?") then
      check(string.match(url, "^(https?://[^%?]+)")..newurl)
    elseif not (string.match(newurl, "^https?:\\?/\\?//?/?")
        or string.match(newurl, "^[/\\]")
        or string.match(newurl, "^[jJ]ava[sS]cript:")
        or string.match(newurl, "^[mM]ail[tT]o:")
        or string.match(newurl, "^vine:")
        or string.match(newurl, "^android%-app:")
        or string.match(newurl, "^%${")) then
      check(string.match(url, "^(https?://.+/)")..newurl)
    end
  end
  
  if allowed(url) and not (string.match(url, "google%-code%-archive%-downloads") or status_code == 404) then
    html = read_file(file)

    if string.match(url, "^https?://[^/]*googleapis%.com/storage/v1/b/google%-code%-archive/o/")
       and string.match(url, "%.json") then
      local json_ = load_json_file(html)

      if string.match(url, "%-page%-[0-9]+%.json") then
        local start = string.match(url, "^(.+page%-)[0-9]+%.json.+$")
        local end_ = string.match(url, "^.+page%-[0-9]+(%.json.+)$")
        local maxpage = json_["totalPages"]
        if not json_["totalPages"] then
            maxpage = json_["TotalPages"]
        end
        for i = 1, maxpage do
          check(start .. tostring(i) .. end_)
          if string.match(url, "source%-page%-[0-9]+%.json") then
            check("https://code.google.com/archive/p/sqlany-django/source/default/source?page=" .. tostring(i))
          elseif string.match(url, "commits%-page%-[0-9]+%.json") then
            check("https://code.google.com/archive/p/sqlany-django/source/default/commits?page=" .. tostring(i))
          elseif string.match(url, "issues%-page%-[0-9]+%.json") then
            check("https://code.google.com/archive/p/sqlany-django/issues?page=" .. tostring(i))
          elseif string.match(url, "downloads%-page%-[0-9]+%.json") then
            check("https://code.google.com/archive/p/sqlany-django/downloads?page=" .. tostring(i))
          end
        end
      end

      if string.match(url, "issues%-page%-[0-9]+%.json") then
        for _, issue in pairs(json_["issues"]) do
          check("https://www.googleapis.com/storage/v1/b/google-code-archive/o/v2%2Fcode.google.com%2F" .. item_value .. "%2Fissues%2Fissue-" .. issue["id"] .. ".json?alt=media&stripTrailingSlashes=false")
          check("https://code.google.com/archive/p/" .. item_value .. "/issues/" .. issue["id"])
        end
      end

      if string.match(url, "wikis%.json") then
        for _, wikifile in pairs(json_["WikiFiles"]) do
          check("https://www.googleapis.com/storage/v1/b/google-code-archive/o/v2%2Fcode.google.com%2F" .. item_value .. "%2Fwiki" .. string.gsub(wikifile, "/", "%%2F") .. "?alt=media")
          check("https://code.google.com/archive/p/" .. item_value .. "/wikis" .. wikifile)
        end
      end

      if string.match(url, "downloads%-page%-[0-9]+%.json") then
        for _, download in pairs(json_["downloads"]) do
          check("https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/" .. item_value .. "/" .. download["filename"])
        end
      end
    end

    for newurl in string.gmatch(html, '([^"]+)') do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "([^']+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, ">%s*([^<%s]+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "href='([^']+)'") do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, 'href="([^"]+)"') do
      checknewshorturl(newurl)
    end
  end

  return urls
end
  

wget.callbacks.httploop_result = function(url, err, http_stat)
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. ".  \n")
  io.stdout:flush()

  if (status_code >= 200 and status_code <= 399) then
    downloaded[url["url"]] = true
  end

  if abortgrab == true then
    io.stdout:write("ABORTING...\n")
    return wget.actions.ABORT
  end
  
  if status_code >= 500 or
    (status_code >= 400 and status_code ~= 404 and status_code ~= 410) or
    status_code == 0 then
    io.stdout:write("Server returned "..http_stat.statcode.." ("..err.."). Sleeping.\n")
    io.stdout:flush()
    os.execute("sleep 1")
    tries = tries + 1
    if tries >= 5 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      if allowed(url["url"]) then
        return wget.actions.ABORT
      else
        return wget.actions.EXIT
      end
    else
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  local sleep_time = 0

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end

wget.callbacks.before_exit = function(exit_status, exit_status_string)
  if abortgrab == true then
    return wget.exits.IO_FAIL
  end
  return exit_status
end