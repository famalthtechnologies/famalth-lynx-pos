Set objShell = CreateObject("Wscript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objEnv = objShell.Environment("Process")

' Get the exact folder where this VBScript is located
strPath = objFSO.GetParentFolderName(WScript.ScriptFullName)

' Set the working directory to that folder
objShell.CurrentDirectory = strPath

' Use the API port selected by the Famalth Lynx installer or configured in server_config.json
strPortFile = strPath & "\server_port.txt"
If objFSO.FileExists(strPortFile) Then
    Set objFile = objFSO.OpenTextFile(strPortFile, 1)
    strPort = Trim(objFile.ReadAll)
    objFile.Close
    If IsNumeric(strPort) Then objEnv("PORT") = strPort
End If

' Fallback: read local port from server_config.json if server_port.txt is missing
If objEnv("PORT") = "" Then
    strConfigFile = strPath & "\server_config.json"
    If objFSO.FileExists(strConfigFile) Then
        Set objFile = objFSO.OpenTextFile(strConfigFile, 1)
        strJson = objFile.ReadAll
        objFile.Close
        Set regEx = CreateObject("VBScript.RegExp")
        regEx.Pattern = "baseUrl""\s*:\s*""https?://(?:localhost|127\.0\.0\.1|0\.0\.0\.0):(\d+)"""
        regEx.IgnoreCase = True
        Set matches = regEx.Execute(strJson)
        If matches.Count > 0 Then
            strPort = matches(0).SubMatches(0)
            If IsNumeric(strPort) Then objEnv("PORT") = strPort
        End If
        Set regEx = Nothing
    End If
End If

' Add PostgreSQL bin directory to process PATH and FAMALTH_PG_BIN
strPgBin = ""
strPgBinFile = strPath & "\pg_bin.txt"
If objFSO.FileExists(strPgBinFile) Then
    Set objFile = objFSO.OpenTextFile(strPgBinFile, 1)
    strPgBin = Trim(objFile.ReadAll)
    objFile.Close
End If

If strPgBin = "" Or Not objFSO.FolderExists(strPgBin) Then
    strDefaultPgBin = strPath & "\PostgreSQL18\bin"
    If objFSO.FolderExists(strDefaultPgBin) Then
        strPgBin = strDefaultPgBin
    End If
End If

If strPgBin <> "" And objFSO.FolderExists(strPgBin) Then
    objEnv("FAMALTH_PG_BIN") = strPgBin
    objEnv("PATH") = strPgBin & ";" & objEnv("PATH")
End If

' Run server.exe silently (0) from that exact folder
objShell.Run chr(34) & strPath & "\server.exe" & chr(34), 0, False

Set objShell = Nothing
Set objFSO = Nothing
Set objEnv = Nothing
