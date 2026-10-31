Set objShell = CreateObject("Wscript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objEnv = objShell.Environment("Process")

' Get the exact folder where this VBScript is located
strPath = objFSO.GetParentFolderName(WScript.ScriptFullName)

' Set the working directory to that folder
objShell.CurrentDirectory = strPath

' Use the API port selected by the Famalth Lynx installer.
strPortFile = strPath & "\server_port.txt"
If objFSO.FileExists(strPortFile) Then
    Set objFile = objFSO.OpenTextFile(strPortFile, 1)
    strPort = Trim(objFile.ReadAll)
    objFile.Close
    If IsNumeric(strPort) Then objEnv("PORT") = strPort
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
