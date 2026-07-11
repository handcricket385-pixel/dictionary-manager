require "import"
import "android.widget.*"
import "android.view.*"
import "android.content.*"
import "android.graphics.*"
import "android.util.TypedValue"
import "cjson"
import "java.io.File"
import "java.lang.String"
import "android.graphics.drawable.GradientDrawable"
import "android.os.Handler"
import "java.lang.Runnable"
import "android.net.Uri"
import "android.os.StrictMode"
import "java.lang.Class"
import "java.util.Arrays"
import "java.util.Comparator"

local ctx = activity or service

local StrictModeVmPolicyBuilder = Class.forName("android.os.StrictMode$VmPolicy$Builder")
local builder = StrictModeVmPolicyBuilder.newInstance()
StrictMode.setVmPolicy(builder.build())

local dataPath = "/storage/emulated/0/Dictionary_Pro_Advanced.json"
local ed1, ed2

function dip2px(dp)
  return TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, dp, ctx.getResources().getDisplayMetrics())
end

function showToast(msg)
  Toast.makeText(ctx, msg, Toast.LENGTH_SHORT).show()
end

function loadData()
  local file = File(dataPath)
  local defaultData = { 
    categories = {
      "All", "General", "Personal", "Work", "Tech", "Social Media", 
      "Finance", "Education", "Links", "Shopping", "Health", 
      "Travel", "Important", "Passwords", "Banking", "Gaming", 
      "Office", "Quotes", "Address", "Emails", "Notes", "Contacts"
    }, 
    entries = {} 
  }
  
  if file.exists() then
    local f = io.open(dataPath, "r")
    local content = f:read("*a")
    f:close()
    local success, data = pcall(cjson.decode, content)
    if success and data then 
      data.categories = defaultData.categories
      return data 
    end
  end
  return defaultData
end

function saveData(data)
  local f = io.open(dataPath, "w")
  f:write(cjson.encode(data))
  f:close()
end

local dictData = loadData()
local entryContainer, categorySpinner, mainDialog, searchInput

function getRoundedBg(colorStr, radius, strokeColor)
  local drawable = GradientDrawable()
  drawable.setShape(GradientDrawable.RECTANGLE)
  drawable.setCornerRadius(dip2px(radius))
  drawable.setColor(Color.parseColor(colorStr))
  if strokeColor then drawable.setStroke(dip2px(1), Color.parseColor(strokeColor)) end
  return drawable
end

function showDetailDialog(entry, index)
  local detailLayout = LinearLayout(ctx)
  detailLayout.setOrientation(1)
  detailLayout.setPadding(dip2px(20), dip2px(15), dip2px(20), dip2px(15))
  
  local titleText = TextView(ctx)
  titleText.setText(entry.word .. " (" .. entry.category .. ")")
  titleText.setTextSize(20)
  titleText.setTypeface(Typeface.DEFAULT_BOLD)
  titleText.setTextColor(Color.parseColor("#2C3E50"))
  titleText.setGravity(Gravity.CENTER)
  detailLayout.addView(titleText)
  
  local line = View(ctx)
  line.setBackgroundColor(Color.parseColor("#BDC3C7"))
  local lineParams = LinearLayout.LayoutParams(-1, dip2px(1))
  lineParams.setMargins(0, dip2px(10), 0, dip2px(10))
  line.setLayoutParams(lineParams)
  detailLayout.addView(line)
  
  local scrollView = ScrollView(ctx)
  scrollView.setLayoutParams(LinearLayout.LayoutParams(-1, dip2px(300)))
  
  local contentText = TextView(ctx)
  contentText.setText(entry.meaning)
  contentText.setTextSize(16)
  contentText.setTextColor(Color.parseColor("#34495E"))
  contentText.setPadding(dip2px(10), dip2px(10), dip2px(10), dip2px(10))
  scrollView.addView(contentText)
  detailLayout.addView(scrollView)
  
  local btnLayout = LinearLayout(ctx)
  btnLayout.setOrientation(0)
  btnLayout.setPadding(0, dip2px(20), 0, 0)
  btnLayout.setGravity(Gravity.CENTER)
  
  local copyBtn = Button(ctx)
  copyBtn.setText("Copy")
  copyBtn.setTextSize(12)
  copyBtn.setBackgroundColor(Color.parseColor("#3498DB"))
  copyBtn.setTextColor(Color.WHITE)
  copyBtn.setPadding(dip2px(12), dip2px(6), dip2px(12), dip2px(6))
  copyBtn.setLayoutParams(LinearLayout.LayoutParams(-2, -2))
  copyBtn.onClick = function()
    local cm = ctx.getSystemService(Context.CLIPBOARD_SERVICE)
    cm.setPrimaryClip(ClipData.newPlainText("text", entry.meaning))
    showToast("Copied to clipboard")
  end
  btnLayout.addView(copyBtn)
  
  local shareBtn = Button(ctx)
  shareBtn.setText("Share")
  shareBtn.setTextSize(12)
  shareBtn.setBackgroundColor(Color.parseColor("#25D366"))
  shareBtn.setTextColor(Color.WHITE)
  shareBtn.setPadding(dip2px(12), dip2px(6), dip2px(12), dip2px(6))
  shareBtn.setLayoutParams(LinearLayout.LayoutParams(-2, -2))
  shareBtn.onClick = function()
    if detailDialog then detailDialog.dismiss() end
    if mainDialog then mainDialog.dismiss() end
    
    local shareIntent = Intent(Intent.ACTION_SEND)
    shareIntent.setType("text/plain")
    shareIntent.putExtra(Intent.EXTRA_TEXT, "Title: " .. entry.word .. "\n\nContent: " .. entry.meaning)
    
    local chooser = Intent.createChooser(shareIntent, "Share via")
    chooser.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    ctx.startActivity(chooser)
  end
  btnLayout.addView(shareBtn)
  
  local editBtn = Button(ctx)
  editBtn.setText("Edit")
  editBtn.setTextSize(12)
  editBtn.setBackgroundColor(Color.parseColor("#F39C12"))
  editBtn.setTextColor(Color.WHITE)
  editBtn.setPadding(dip2px(12), dip2px(6), dip2px(12), dip2px(6))
  editBtn.setLayoutParams(LinearLayout.LayoutParams(-2, -2))
  editBtn.onClick = function()
    if detailDialog then detailDialog.dismiss() end
    showAddEntryDialog(entry, index)
  end
  btnLayout.addView(editBtn)
  
  local deleteBtn = Button(ctx)
  deleteBtn.setText("Delete")
  deleteBtn.setTextSize(12)
  deleteBtn.setBackgroundColor(Color.parseColor("#E74C3C"))
  deleteBtn.setTextColor(Color.WHITE)
  deleteBtn.setPadding(dip2px(12), dip2px(6), dip2px(12), dip2px(6))
  deleteBtn.setLayoutParams(LinearLayout.LayoutParams(-2, -2))
  deleteBtn.onClick = function()
    LuaDialog(ctx).setTitle("Confirm Delete")
      .setMessage("Delete \"" .. entry.word .. "\"?")
      .setPositiveButton("Delete", function()
        table.remove(dictData.entries, index)
        saveData(dictData)
        local selectedCat = "All"
        if categorySpinner then
          selectedCat = dictData.categories[categorySpinner.getSelectedItemPosition() + 1]
        end
        local searchText = ""
        if searchInput then
          searchText = tostring(searchInput.getText())
        end
        refreshEntriesList(searchText, selectedCat)
        showToast("Entry deleted")
      end)
      .setNegativeButton("Cancel", nil)
      .show()
  end
  btnLayout.addView(deleteBtn)
  
  detailLayout.addView(btnLayout)
  
  detailDialog = LuaDialog(ctx).setTitle(entry.word).setView(detailLayout).setPositiveButton("Close", nil).show()
  
  return detailDialog
end

function refreshEntriesList(filterQuery, filterCategory)
  entryContainer.removeAllViews()
  for i, entry in ipairs(dictData.entries) do
    local matchCat = (filterCategory == "All") or (entry.category == filterCategory)
    local matchQuery = (not filterQuery) or (filterQuery == "") or 
                       (entry.word:lower():find(filterQuery:lower()))
    
    if matchCat and matchQuery then
      local card = LinearLayout(ctx)
      card.setOrientation(1)
      card.setBackground(getRoundedBg("#FFFFFF", 12, "#D1D9E6"))
      local params = LinearLayout.LayoutParams(-1, -2)
      params.setMargins(0, 0, 0, dip2px(12))
      card.setLayoutParams(params)
      card.setPadding(dip2px(15), dip2px(15), dip2px(15), dip2px(15))
      
      local titleTxt = TextView(ctx)
      titleTxt.setText(entry.word .. " (" .. entry.category .. ")")
      titleTxt.setTextSize(18)
      titleTxt.setTypeface(Typeface.DEFAULT_BOLD)
      titleTxt.setTextColor(Color.parseColor("#2C3E50"))
      titleTxt.onClick = function()
        showDetailDialog(entry, i)
      end
      card.addView(titleTxt)
      
      entryContainer.addView(card)
    end
  end
end

function showAddEntryDialog(item, index, defaultTitle, defaultMeaning)
  local lay = LinearLayout(ctx)
  lay.setOrientation(1)
  lay.setPadding(dip2px(20), dip2px(10), dip2px(20), dip2px(10))

  local spin = Spinner(ctx)
  spin.setAdapter(ArrayAdapter(ctx, android.R.layout.simple_spinner_item, String(dictData.categories)))
  lay.addView(spin)

  ed1 = EditText(ctx) 
  ed1.setHint("Title") 
  lay.addView(ed1)
  
  ed2 = EditText(ctx) 
  ed2.setHint("Content") 
  ed2.setMinLines(3) 
  lay.addView(ed2)

  if item then 
    ed1.setText(item.word) 
    ed2.setText(item.meaning) 
    for i, cat in ipairs(dictData.categories) do
      if cat == item.category then
        spin.setSelection(i - 1)
        break
      end
    end
  elseif defaultTitle or defaultMeaning then
    if defaultTitle then ed1.setText(defaultTitle) end
    if defaultMeaning then ed2.setText(defaultMeaning) end
  end

  local saveDialog = LuaDialog(ctx).setTitle("Save Entry").setView(lay)
  saveDialog.setPositiveButton("Save", function()
    local t, m = tostring(ed1.getText()), tostring(ed2.getText())
    local cat = dictData.categories[spin.getSelectedItemPosition() + 1]
    if #t > 0 then
      if item then 
        dictData.entries[index] = {word=t, meaning=m, category=cat}
      else 
        table.insert(dictData.entries, 1, {word=t, meaning=m, category=cat})
      end
      saveData(dictData)
      local selectedCat = "All"
      if categorySpinner then
        selectedCat = dictData.categories[categorySpinner.getSelectedItemPosition() + 1]
      end
      local searchText = ""
      if searchInput then
        searchText = tostring(searchInput.getText())
      end
      refreshEntriesList(searchText, selectedCat)
      showToast("Entry saved")
      saveDialog.dismiss()
    else
      showToast("Title cannot be empty")
    end
  end)
  saveDialog.setNegativeButton("Cancel", nil)
  saveDialog.show()
end

function handleSelectedInternalFile(fileObj)
  local fileName = tostring(fileObj.getName())
  local ext = fileName:lower()
  local fileContent = ""
  
  if ext:find("%.txt$") or ext:find("%.csv$") or ext:find("%.doc$") or ext:find("%.docx$") then
    local success, content = pcall(function()
      local f = io.open(fileObj.getAbsolutePath(), "r")
      local txt = f:read("*a")
      f:close()
      return txt
    end)
    if success then 
      fileContent = content 
    else
      fileContent = "Error reading file content."
    end
  else
    showToast("Unsupported file type")
    return
  end
  
  showAddEntryDialog(nil, nil, fileName, fileContent)
end

function showInternalFilePicker(currentPath)
  local pickerLayout = LinearLayout(ctx)
  pickerLayout.setOrientation(1)
  pickerLayout.setPadding(dip2px(15), dip2px(15), dip2px(15), dip2px(15))
  
  local pathTxt = TextView(ctx)
  pathTxt.setText(currentPath)
  pathTxt.setTextSize(14)
  pathTxt.setTextColor(Color.parseColor("#7F8C8D"))
  pathTxt.setPadding(0, 0, 0, dip2px(10))
  pickerLayout.addView(pathTxt)
  
  local scroll = ScrollView(ctx)
  local listContainer = LinearLayout(ctx)
  listContainer.setOrientation(1)
  
  local currentDir = File(currentPath)
  local filesList = currentDir.listFiles()
  
  if currentPath ~= "/storage/emulated/0" then
    local backBtn = Button(ctx)
    backBtn.setText(".. (Go Back)")
    backBtn.setGravity(Gravity.LEFT or Gravity.CENTER_VERTICAL)
    backBtn.setBackgroundColor(Color.parseColor("#BDC3C7"))
    backBtn.setTextColor(Color.BLACK)
    backBtn.onClick = function()
      pickerDialog.dismiss()
      showInternalFilePicker(tostring(currentDir.getParent()))
    end
    listContainer.addView(backBtn)
  end
  
  if filesList then
    -- Convert Java array to Lua table for perfect A-Z and type sorting
    local sortedList = {}
    for i = 0, #filesList - 1 do
      table.insert(sortedList, filesList[i])
    end
    
    table.sort(sortedList, function(a, b)
      if a.isDirectory() and not b.isDirectory() then
        return true
      elseif not a.isDirectory() and b.isDirectory() then
        return false
      else
        return tostring(a.getName()):lower() < tostring(b.getName()):lower()
      end
    end)
    
    for _, f in ipairs(sortedList) do
      local name = tostring(f.getName())
      local isDir = f.isDirectory()
      
      local validFile = false
      if isDir then
        validFile = true
      else
        local lowerName = name:lower()
        if lowerName:find("%.txt$") or lowerName:find("%.csv$") or lowerName:find("%.doc$") or lowerName:find("%.docx$") then
          validFile = true
        end
      end
      
      if validFile then
        local itemBtn = Button(ctx)
        if isDir then
          itemBtn.setText("[Folder] " .. name)
          itemBtn.setBackgroundColor(Color.parseColor("#34495E"))
        else
          itemBtn.setText("[File] " .. name)
          itemBtn.setBackgroundColor(Color.parseColor("#FFFFFF"))
          itemBtn.setTextColor(Color.BLACK)
        end
        
        itemBtn.setGravity(Gravity.LEFT or Gravity.CENTER_VERTICAL)
        local itemParams = LinearLayout.LayoutParams(-1, -2)
        itemParams.setMargins(0, dip2px(4), 0, dip2px(4))
        itemBtn.setLayoutParams(itemParams)
        
        itemBtn.onClick = function()
          pickerDialog.dismiss()
          if isDir then
            showInternalFilePicker(f.getAbsolutePath())
          else
            handleSelectedInternalFile(f)
          end
        end
        listContainer.addView(itemBtn)
      end
    end
  end
  
  scroll.addView(listContainer)
  pickerLayout.addView(scroll)
  
  pickerDialog = LuaDialog(ctx).setTitle("Select Document").setView(pickerLayout).setNegativeButton("Cancel", nil).show()
end

function showMainDashboard()
  local root = LinearLayout(ctx)
  root.setOrientation(1)
  root.setBackgroundColor(Color.parseColor("#F4F7F6"))

  local top = LinearLayout(ctx)
  top.setOrientation(0)
  top.setBackgroundColor(Color.parseColor("#2C3E50"))
  top.setPadding(dip2px(15), dip2px(15), dip2px(15), dip2px(15))
  top.setGravity(Gravity.CENTER_VERTICAL)
  
  local title = TextView(ctx)
  title.setText("Dictionary Manager Pro")
  title.setTextColor(Color.WHITE)
  title.setTextSize(18)
  title.setTypeface(Typeface.DEFAULT_BOLD)
  title.setLayoutParams(LinearLayout.LayoutParams(0, -2, 1))
  top.addView(title)
  
  local rightContainer = LinearLayout(ctx)
  rightContainer.setOrientation(1)
  rightContainer.setGravity(Gravity.RIGHT)
  
  local devName = TextView(ctx)
  devName.setText("Developed by Mohsin Ali")
  devName.setTextColor(Color.parseColor("#BDC3C7"))
  devName.setTextSize(12)
  rightContainer.addView(devName)
  
  local selectFileBtn = TextView(ctx)
  selectFileBtn.setText("Select file")
  selectFileBtn.setTextColor(Color.parseColor("#25D366"))
  selectFileBtn.setTextSize(12)
  selectFileBtn.setTypeface(Typeface.DEFAULT_BOLD)
  selectFileBtn.setPadding(0, dip2px(4), 0, 0)
  selectFileBtn.setClickable(true)
  selectFileBtn.onClick = function()
    showInternalFilePicker("/storage/emulated/0")
  end
  rightContainer.addView(selectFileBtn)
  
  top.addView(rightContainer)
  root.addView(top)

  searchInput = EditText(ctx)
  searchInput.setHint("Search...")
  searchInput.setPadding(dip2px(10), dip2px(10), dip2px(10), dip2px(10))
  searchInput.setBackground(getRoundedBg("#FFFFFF", 10, "#D1D9E6"))
  local sp = LinearLayout.LayoutParams(-1, -2)
  sp.setMargins(dip2px(15), dip2px(10), dip2px(15), 0)
  searchInput.setLayoutParams(sp)
  searchInput.addTextChangedListener({onTextChanged=function(s) 
    local selectedCat = dictData.categories[categorySpinner.getSelectedItemPosition() + 1]
    refreshEntriesList(tostring(s), selectedCat)
  end})
  root.addView(searchInput)

  local bar = LinearLayout(ctx)
  bar.setOrientation(0)
  bar.setPadding(dip2px(15), dip2px(10), dip2px(15), 0)
  bar.setGravity(Gravity.CENTER_VERTICAL)
  
  categorySpinner = Spinner(ctx)
  categorySpinner.setLayoutParams(LinearLayout.LayoutParams(0, -2, 1))
  categorySpinner.setAdapter(ArrayAdapter(ctx, android.R.layout.simple_spinner_item, String(dictData.categories)))
  categorySpinner.onItemSelected = function(p, v, pos, id)
    local selectedCat = dictData.categories[pos+1]
    refreshEntriesList(tostring(searchInput.getText()), selectedCat)
  end
  bar.addView(categorySpinner)
  
  local addBtn = Button(ctx)
  addBtn.setText("Add")
  addBtn.setTextSize(14)
  addBtn.setBackgroundColor(Color.parseColor("#27AE60"))
  addBtn.setTextColor(Color.WHITE)
  addBtn.setPadding(dip2px(15), dip2px(8), dip2px(15), dip2px(8))
  addBtn.onClick = function() showAddEntryDialog() end
  bar.addView(addBtn)
  
  root.addView(bar)

  local scroll = ScrollView(ctx)
  entryContainer = LinearLayout(ctx)
  entryContainer.setOrientation(1)
  entryContainer.setPadding(dip2px(15), dip2px(10), dip2px(15), dip2px(10))
  scroll.addView(entryContainer)
  root.addView(scroll)

  local bottomBar = LinearLayout(ctx)
  bottomBar.setOrientation(0)
  bottomBar.setPadding(dip2px(15), dip2px(10), dip2px(15), dip2px(10))
  bottomBar.setGravity(Gravity.CENTER)
  
  local aboutBtn = Button(ctx)
  aboutBtn.setText("About")
  aboutBtn.setTextSize(14)
  aboutBtn.setBackgroundColor(Color.parseColor("#34495E"))
  aboutBtn.setTextColor(Color.WHITE)
  aboutBtn.setPadding(dip2px(20), dip2px(10), dip2px(20), dip2px(10))
  aboutBtn.setLayoutParams(LinearLayout.LayoutParams(0, -2, 1))
  aboutBtn.onClick = function()
    local aboutLayout = LinearLayout(ctx)
    aboutLayout.setOrientation(1)
    aboutLayout.setPadding(dip2px(20), dip2px(20), dip2px(20), dip2px(20))
    
    local devText = TextView(ctx)
    devText.setText("Developer: Developed by Mohsin Ali")
    devText.setTextSize(16)
    devText.setTypeface(Typeface.DEFAULT_BOLD)
    devText.setTextColor(Color.parseColor("#2C3E50"))
    aboutLayout.addView(devText)
    
    local space1 = View(ctx)
    space1.setLayoutParams(LinearLayout.LayoutParams(-1, dip2px(15)))
    aboutLayout.addView(space1)
    
    local versionText = TextView(ctx)
    versionText.setText("Version 1.0")
    versionText.setTextSize(14)
    versionText.setTextColor(Color.parseColor("#7F8C8D"))
    aboutLayout.addView(versionText)
    
    local space2 = View(ctx)
    space2.setLayoutParams(LinearLayout.LayoutParams(-1, dip2px(15)))
    aboutLayout.addView(space2)
    
    local aboutTitle = TextView(ctx)
    aboutTitle.setText("About Dictionary Manager Pro")
    aboutTitle.setTextSize(16)
    aboutTitle.setTypeface(Typeface.DEFAULT_BOLD)
    aboutTitle.setTextColor(Color.parseColor("#2C3E50"))
    aboutLayout.addView(aboutTitle)
    
    local space3 = View(ctx)
    space3.setLayoutParams(LinearLayout.LayoutParams(-1, dip2px(10)))
    aboutLayout.addView(space3)
    
    local descText = TextView(ctx)
    descText.setText("This app helps you save and manage all your important information in one place.\n\nFeatures:\n• Save passwords, contacts, notes, addresses, and more\n• Organize everything with categories\n• Search quickly by title\n• Copy, share, edit, or delete entries\n\nHow to use:\n1. Select a category from the dropdown\n2. Click Add button to create new entry\n3. Enter Title and Content\n4. Click Save\n5. Tap on any title to view full details with Copy/Share/Edit/Delete options")
    descText.setTextSize(12)
    descText.setTextColor(Color.parseColor("#34495E"))
    descText.setPadding(0, dip2px(5), 0, 0)
    aboutLayout.addView(descText)
    
    LuaDialog(ctx).setTitle("About")
      .setView(aboutLayout)
      .setPositiveButton("Back to Main Menu", nil)
      .show()
  end
  bottomBar.addView(aboutBtn)
  
  local exitBtn = Button(ctx)
  exitBtn.setText("Exit")
  exitBtn.setTextSize(14)
  exitBtn.setBackgroundColor(Color.parseColor("#E74C3C"))
  exitBtn.setTextColor(Color.WHITE)
  exitBtn.setPadding(dip2px(20), dip2px(10), dip2px(20), dip2px(10))
  exitBtn.setLayoutParams(LinearLayout.LayoutParams(0, -2, 1))
  exitBtn.onClick = function()
    if mainDialog then mainDialog.dismiss() end
  end
  bottomBar.addView(exitBtn)
  
  root.addView(bottomBar)

  mainDialog = LuaDialog(ctx).setView(root).show()
  refreshEntriesList(nil, "All")
end

showMainDashboard()