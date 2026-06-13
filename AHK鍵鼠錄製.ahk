#Requires AutoHotkey v2.0
#SingleInstance Force

global 錄製狀態 := false
global 執行狀態 := false
global 動作列表 := []
global 開始時間 := 0
global 腳本目錄 := A_ScriptDir "\SavedScripts"

; 目前被正式勾選選定的腳本檔名
global 目前選定腳本 := ""

; 自我修改熱鍵區塊 (動態改寫目標)
global 錄製鍵名 := "未設定"
global 執行鍵名 := "未設定"
global 實際錄製鍵 := ""
global 實際執行鍵 := ""

global 最後滑鼠X := 0
global 最後滑鼠Y := 0

global 全域_display結果 := ""
global 全域_syntax結果 := ""
global 全域_ih := ""
global 全域_capGui := ""
global 滑鼠鉤子物件 := 0

if !DirExist(腳本目錄)
    DirCreate(腳本目錄)

; 註冊初始熱鍵
更新系統熱鍵()

; 建立主視窗
MyGui := Gui("+AlwaysOnTop", "鍵鼠紀錄器")
MyGui.SetFont("s10", "Microsoft JhengHei")

MyGui.Add("Text", "w180 h25 +0x200", "錄製鍵: " 錄製鍵名)
MyGui.Add("Button", "x+10 w120 h26", "修改錄製").OnEvent("Click", (*) => 設定熱鍵("錄製"))

MyGui.Add("Text", "xm y+10 w180 h25 +0x200", "執行鍵: " 執行鍵名)
MyGui.Add("Button", "x+10 w120 h26", "修改執行").OnEvent("Click", (*) => 設定熱鍵("執行"))

MyGui.Add("Text", "xm y+10 w70 h25 +0x200", "執行次數:")
Edit次數 := MyGui.Add("Edit", "x+5 w105 h24 Number v執行次數", "1")
Edit次數.OnEvent("Change", 檢查次數提示)
MyGui.Add("Button", "x+10 w120 h26", "儲存腳本").OnEvent("Click", 儲存腳本)

MyGui.Add("Text", "xm y+12 w70 h20", "執行速率:")
Text速度值 := MyGui.Add("Text", "x+5 w105 h20 +0x200", "1.0 倍速")
Slider速度 := MyGui.Add("Slider", "xm y+2 w310 h30 ToolTip Range1-80 v執行速度", 10)
Slider速度.OnEvent("Change", 變更速度文字)

MyGui.Add("Text", "xm y+10", "請勾選要執行的腳本：")
LV := MyGui.Add("ListView", "v腳本列表 xm y+5 w310 r8 +Checked -HDR -Multi", ["檔名"])
LV.OnEvent("ItemCheck", 處理列表勾選)

MyGui.Add("Button", "xm y+10 w310 h30", "刪除選定項目").OnEvent("Click", 刪除選定)

MyGui.Show("w330")
刷新列表()

; =================================================================
; 介面即時提示與拉桿邏輯
; =================================================================

檢查次數提示(CtrlObj, *) {
    if (CtrlObj.Value == "0") {
        CoordMode("ToolTip", "Window")
        CtrlObj.GetPos(&x, &y, &w, &h)
        ToolTip("∞ 無限循環模式", x + w + 10, y + 2, 2)
        SetTimer(() => ToolTip(,,, 2), -2000)
    } else {
        ToolTip(,,, 2)
    }
}

變更速度文字(CtrlObj, *) {
    global Text速度值
    實際倍率 := CtrlObj.Value / 10
    Text速度值.Value := Format("{:.1f} 倍速", 實際倍率)
}

; =================================================================
; 介面勾選邏輯
; =================================================================

處理列表勾選(LVObj, itemIndex, checked) {
    global 目前選定腳本
    LVObj.OnEvent("ItemCheck", 處理列表勾選, 0)
    if (checked) {
        Loop LVObj.GetCount() {
            if (A_Index != itemIndex) {
                LVObj.Modify(A_Index, "-Check")
            }
        }
        currentlySelectedScript := LVObj.GetText(itemIndex, 1)
        目前選定腳本 := currentlySelectedScript
    } else {
        if (LVObj.GetText(itemIndex, 1) == 目前選定腳本) {
            目前選定腳本 := ""
        }
    }
    LVObj.OnEvent("ItemCheck", 處理列表勾選, 1)
}

刷新列表(*) {
    global 腳本目錄, MyGui, 目前選定腳本
    LV := MyGui["腳本列表"]
    LV.Delete()
    LV.OnEvent("ItemCheck", 處理列表勾選, 0)
    Loop Files, 腳本目錄 "\*.ahk"
    {
        rowNum := LV.Add(, A_LoopFileName)
        if (A_LoopFileName == 目前選定腳本) {
            LV.Modify(rowNum, "+Check")
        }
    }
    LV.ModifyCol(1, 290)
    LV.OnEvent("ItemCheck", 處理列表勾選, 1)
}

刪除選定(*) {
    global MyGui, 腳本目錄, 目前選定腳本
    LV := MyGui["腳本列表"]
    focusedRow := LV.GetNext(0, "F")
    if (focusedRow == 0) {
        MsgBox("請先用滑鼠點擊選中列表中的腳本項目再按刪除。")
        return
    }
    
    點選檔名 := LV.GetText(focusedRow, 1)
    目標路徑 := 腳本目錄 "\" 點選檔名
    
    確認 := MsgBox("您確定要永久刪除腳本「" 點選檔名 "」嗎？", "確認刪除", "YesNo Icon!")
    if (確認 == "Yes") {
        try {
            FileDelete(目標路徑)
            if (點選檔名 == 目前選定腳本) {
                目前選定腳本 := ""
            }
            刷新列表()
            MsgBox("檔案已成功刪除。")
        } catch {
            MsgBox("刪除失敗，檔案可能正在被其他程式使用中。")
        }
    }
}

; =================================================================
; 自我修改與熱鍵註冊邏輯
; =================================================================

更新系統熱鍵() {
    global 實際錄製鍵, 實際執行鍵
    try {
        Hotkey(實際錄製鍵, 錄製觸發, "On")
        Hotkey(實際執行鍵, 執行觸發, "On")
    } catch {
        MsgBox("熱鍵設定失敗，請重新設定熱鍵。")
    }
}

設定熱鍵(類型) {
    global 全域_display結果, 全域_syntax結果, 全域_ih, 全域_capGui
    全域_display結果 := ""
    全域_syntax結果 := ""
    
    全域_capGui := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox", "請按下熱鍵")
    全域_capGui.SetFont("s10")
    全域_capGui.Add("Text", "w280 Center", "請按下您的組合鍵（例如: Ctrl+Alt+K）`n按下後請點擊下方確定按鍵。")
    
    btn確定 := 全域_capGui.Add("Button", "x100 w100 y+15", "確定")
    btn確定.OnEvent("Click", 按下確定_點擊.Bind(類型))
    全域_capGui.Show("w300")
    
    全域_ih := InputHook("L0 V")
    全域_ih.KeyOpt("{All}", "N")
    全域_ih.OnKeyDown := 全域_偵測按鍵
    全域_ih.Start()
}

全域_偵測按鍵(ih_obj, vk, sc) {
    global 全域_display結果, 全域_syntax結果
    nonModifier := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
    
    if (nonModifier = "Control" || nonModifier = "Alt" || nonModifier = "Shift" || nonModifier = "LWin" || nonModifier = "RWin")
        return
        
    prefixDisplay := ""
    prefixSyntax := ""
    if GetKeyState("Control", "P") {
        prefixDisplay .= "Ctrl+"
        prefixSyntax .= "^"
    }
    if GetKeyState("Alt", "P") {
        prefixDisplay .= "Alt+"
        prefixSyntax .= "!"
    }
    if GetKeyState("Shift", "P") {
        prefixDisplay .= "Shift+"
        prefixSyntax .= "+"
    }
    
    revert := (nonModifier = "a" || nonModifier = "b" || nonModifier = "c" || nonModifier = "d" || nonModifier = "e" || nonModifier = "f" || nonModifier = "g" || nonModifier = "h" || nonModifier = "i" || nonModifier = "j" || nonModifier = "k" || nonModifier = "l" || nonModifier = "m" || nonModifier = "n" || nonModifier = "o" || nonModifier = "p" || nonModifier = "q" || nonModifier = "r" || nonModifier = "s" || nonModifier = "t" || nonModifier = "u" || nonModifier = "v" || nonModifier = "w" || nonModifier = "x" || nonModifier = "y" || nonModifier = "z")
    StrOut := revert ? StrLower(nonModifier) : nonModifier
    
    全域_display結果 := prefixDisplay . nonModifier
    全域_syntax結果 := prefixSyntax . StrOut
}

按下確定_點擊(類型, *) {
    global 全域_display結果, 全域_syntax結果, 全域_ih, 全域_capGui
    全域_ih.Stop()
    全域_capGui.Destroy()
    
    if (全域_syntax結果 == "") {
        MsgBox("未偵測到有效按鍵，未做任何修改。")
        return
    }
    
    自身路徑 := A_ScriptFullPath
    本體文字 := FileRead(自身路徑)
    
    if (類型 == "錄製") {
        本體文字 := RegExReplace(本體文字, "m)^global 錄製鍵名 := \x22.*?\x22", 'global 錄製鍵名 := "' 全域_display結果 '"')
        本體文字 := RegExReplace(本體文字, "m)^global 實際錄製鍵 := \x22.*?\x22", 'global 實際錄製鍵 := "' 全域_syntax結果 '"')
    } else {
        本體文字 := RegExReplace(本體文字, "m)^global 執行鍵名 := \x22.*?\x22", 'global 執行鍵名 := "' 全域_display結果 '"')
        本體文字 := RegExReplace(本體文字, "m)^global 實際執行鍵 := \x22.*?\x22", 'global 實際執行鍵 := "' 全域_syntax結果 '"')
    }
    
    try {
        f := FileOpen(自身路徑, "w", "UTF-8")
        f.Write(本體文字)
        f.Close()
        Reload()
    } catch {
        MsgBox("無法寫入腳本檔案，請確認檔案是否被設為唯讀。")
    }
}

; =================================================================
; 錄製與重播核心邏輯
; =================================================================

錄製觸發(*) {
    global 錄製狀態, 動作列表, 開始時間, 最後滑鼠X, 最後滑鼠Y, ih_rec, 執行狀態, 滑鼠鉤子物件
    if (執行狀態) {
        MsgBox("目前正在重播腳本中，無法開啟錄製！")
        return
    }
    
    錄製狀態 := !錄製狀態
    if (錄製狀態) {
        動作列表 := []
        開始時間 := A_TickCount
        CoordMode("Mouse", "Screen")
        MouseGetPos(&最後滑鼠X, &最後滑鼠Y)
        
        ; 啟用全局滑鼠低階 Hook 監聽按鍵動作
        滑鼠鉤子物件 := Windows滑鼠鉤子(true)
        ; 開啟高精準全局時鐘追蹤（每 40 毫秒強行截取一次游標，不管有沒有按滑鼠）
        SetTimer(紀錄軌跡, 40)
        ih_rec.Start()
        ToolTip("● 錄製中...")
    } else {
        SetTimer(紀錄軌跡, 0)
        ih_rec.Stop()
        Windows滑鼠鉤子(false)
        ToolTip("■ 停止錄製")
        SetTimer(清除提示, -2000)
    }
}

執行觸發(*) {
    global 執行狀態
    if (執行狀態) {
        執行狀態 := false
        ToolTip("■ 已強制中斷重播")
        SetTimer(清除提示, -2000)
    } else {
        開始執行腳本()
    }
}

清除提示() {
    ToolTip()
}

; 核心大改版：不再過濾任何按住狀態，24小時不間斷瘋狂錄製實時位置
紀錄軌跡() {
    global 錄製狀態, 最後滑鼠X, 最後滑鼠Y
    if (錄製狀態) {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&x, &y)
        if (x != 最後滑鼠X || y != 最後滑鼠Y) {
            紀錄動作("MouseMove " x "," y)
            最後滑鼠X := x
            最後滑鼠Y := y
        }
    }
}

紀錄動作(cmd) {
    global 開始時間, 動作列表
    now := A_TickCount
    elapsed := now - 開始時間
    if (elapsed > 0) {
        動作列表.Push("Sleep " elapsed)
    }
    動作列表.Push(cmd)
    開始時間 := now
}

開始執行腳本() {
    global 腳本目錄, MyGui, 執行狀態, 錄製狀態, 目前選定腳本
    if (錄製狀態) {
        MsgBox("目前正在錄製中，無法執行腳本！")
        return
    }
    
    if (目前選定腳本 == "") {
        MsgBox("目前未選定任何腳本！`n請先在列表中「勾選」想要執行的腳本。")
        return
    }
    
    guiVals := MyGui.Submit(false)
    填寫次數 := guiVals.執行次數
    目標次數 := (填寫次數 == "" || 填寫次數 < 0) ? 1 : 填寫次數
    
    拉桿整數 := guiVals.執行速度
    速度倍率 := 拉桿整數 / 10
    
    完整路徑 := 腳本目錄 "\" 目前選定腳本
    if !FileExist(完整路徑) {
        MsgBox("找不到該腳本檔案。")
        return
    }
    
    腳本文字 := FileRead(完整路徑)
    指令陣列 := []
    Loop Parse, 腳本文字, "`n", "`r" {
        line := Trim(A_LoopField)
        if (line == "" || SubStr(line, 1, 1) == "#")
            continue
        指令陣列.Push(line)
    }
    
    if (指令陣列.Length == 0) {
        MsgBox("該腳本內無可執行的動作指令。")
        return
    }
    
    執行狀態 := true
    當前圈數 := 0
    CoordMode("Mouse", "Screen")
    
    Loop {
        if (!執行狀態)
            break
            
        當前圈數++
        if (目標次數 != 0 && 當前圈數 > 目標次數)
            break
            
        ToolTip("▶ 正在重播 (" (目標次數 == 0 ? "無限循環" : 當前圈數 "/" 目標次數) ")`n速度: " 速度倍率 "x`n按執行熱鍵可中斷")
        
        for line in 指令陣列 {
            if (!執行狀態)
                break
                
            if (SubStr(line, 1, 6) = "Sleep ") {
                ms := SubStr(line, 7)
                實際等待 := (速度倍率 <= 0) ? 0 : (ms / 速度倍率)
                if (實際等待 > 0)
                    Sleep(實際等待)
            }
            else if (SubStr(line, 1, 10) = "MouseMove ") {
                pos := StrSplit(SubStr(line, 11), ",")
                if (pos.Length == 2)
                    MouseMove(pos[1], pos[2], 0)
            }
            else if (SubStr(line, 1, 6) = "Click ") {
                ; 支援分離式微秒重播 Click Left Down 或 Click Left Up
                mainBody := SubStr(line, 7)
                Click(mainBody)
            }
            else if (SubStr(line, 1, 6) = "Send '") {
                keyStr := SubStr(line, 7, -1)
                Send(keyStr)
            }
        }
    }
    
    執行狀態 := false
    ToolTip("■ 重播結束")
    SetTimer(清除提示, -2000)
}

儲存腳本(*) {
    global 動作列表, 腳本目錄
    if (動作列表.Length == 0) {
        MsgBox("目前沒有錄製到任何動作，請先按下錄製熱鍵進行錄製！", "儲存失敗", "Icon!")
        return
    }
    
    res := InputBox("請輸入腳本名稱（不需輸入 .ahk）:", "儲存腳本")
    if (res.Result == "OK" && res.Value != "") {
        f := "#Requires AutoHotkey v2.0`n#SingleInstance Force`n`n"
        for line in 動作列表
        {
            f .= line "`n"
        }
        FileAppend(f, 腳本目錄 "\" res.Value ".ahk", "`n")
        刷新列表()
        MsgBox("腳本儲存成功！`n檔名: " res.Value ".ahk")
    }
}

; =================================================================
; 底層鍵盤錄製監聽
; =================================================================

ih_rec := InputHook("V")
ih_rec.KeyOpt("{All}", "N")
ih_rec.OnKeyDown := 錄製鍵盤輸入

錄製鍵盤輸入(hook, vk, sc) {
    global 錄製狀態
    if (錄製狀態) {
        SetTimer(紀錄軌跡, 0)
        紀錄動作("Send '{" GetKeyName(Format("vk{:x}sc{:x}", vk, sc)) "}'")
        SetTimer(紀錄軌跡, 40)
    }
}

; =================================================================
; Windows 低階滑鼠鉤子機制 (全面轉向「時間軸微秒拆解法」)
; =================================================================

Windows滑鼠鉤子(start) {
    static hHook := 0
    static MouseProcCallback := CallbackCreate(LowLevelMouseProc, "Fast", 3)
    
    if (start) {
        if (!hHook) {
            hHook := DllCall("SetWindowsHookEx", "int", 14, "ptr", MouseProcCallback, "ptr", DllCall("GetModuleHandle", "ptr", 0, "ptr"), "uint", 0, "ptr")
        }
        return hHook
    } else {
        if (hHook) {
            DllCall("UnhookWindowsHookEx", "ptr", hHook)
            hHook := 0
        }
        return 0
    }
}

LowLevelMouseProc(nCode, wParam, lParam) {
    global 錄製狀態
    
    if (nCode >= 0 && 錄製狀態) {
        mouseX := NumGet(lParam, 0, "int")
        mouseY := NumGet(lParam, 4, "int")
        
        ; 每當觸發點擊，立刻同步寫入游標位置，然後精準記錄 Down/Up 狀態
        switch wParam {
            case 0x0201: ; WM_LBUTTONDOWN
                紀錄動作("MouseMove " mouseX "," mouseY), 紀錄動作("Click Left Down")
            case 0x0202: ; WM_LBUTTONUP
                紀錄動作("MouseMove " mouseX "," mouseY), 紀錄動作("Click Left Up")
            case 0x0204: ; WM_RBUTTONDOWN
                紀錄動作("MouseMove " mouseX "," mouseY), 紀錄動作("Click Right Down")
            case 0x0205: ; WM_RBUTTONUP
                紀錄動作("MouseMove " mouseX "," mouseY), 紀錄動作("Click Right Up")
            case 0x0207: ; WM_MBUTTONDOWN
                紀錄動作("MouseMove " mouseX "," mouseY), 紀錄動作("Click Middle Down")
            case 0x0208: ; WM_MBUTTONUP
                紀錄動作("MouseMove " mouseX "," mouseY), 紀錄動作("Click Middle Up")
        }
    }
    return DllCall("CallNextHookEx", "ptr", 0, "int", nCode, "ptr", wParam, "ptr", lParam, "ptr")
}