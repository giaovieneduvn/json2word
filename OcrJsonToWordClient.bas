Attribute VB_Name = "OcrJsonToWordClient"
Option Explicit

'=================================================================
' MACRO: Goi thang server web app tu trong Word, khong can mo
' trinh duyet.
'
' LUONG HOAT DONG:
'   1. Hien hop thoai cho ban CHON FILE JSON tren may (giong nhu
'      mo file binh thuong).
'   2. Gui file do len server qua HTTP POST toi /convert_direct
'      (dung WinHttp - co san trong Windows, khong can cai gi them).
'   3. Server tra ve THANG file .docx (khong can goi lan 2).
'   4. Macro luu file .docx do vao thu muc tam tren may, roi
'      TU DONG MO LEN trong Word.
'
' CACH DUNG:
'   1. Sua SERVER_URL ben duoi thanh dia chi server that cua ban
'      (vi du: "http://192.168.1.50:8000" hoac
'      "https://ocr2word.truong-ban.vn").
'   2. Alt+F11 -> Insert Module -> dan code nay vao.
'   3. F5 (hoac gan vao 1 nut/QAT) -> chay Sub ConvertOcrJsonViaServer.
'
' YEU CAU: May tinh phai co ket noi mang toi server (cung mang
' LAN, hoac server public tren Internet voi HTTPS).
'=================================================================

' *** SUA DONG NAY CHO KHOP VOI SERVER THAT CUA BAN ***
Private Const SERVER_URL As String = "http://192.168.1.50:8000/convert_direct"


Sub ConvertOcrJsonViaServer()

    ' ---------- Buoc 1: Chon file JSON tren may ----------
    Dim jsonPath As String
    jsonPath = ChooseJsonFile()
    If jsonPath = "" Then Exit Sub   ' nguoi dung bam Cancel

    Application.StatusBar = "Dang chuyen doi OCR JSON -> Word..."

    ' ---------- Buoc 2: Doc file JSON thanh bytes ----------
    Dim jsonBytes() As Byte
    If Not ReadFileBytes(jsonPath, jsonBytes) Then
        MsgBox "Khong doc duoc file JSON: " & jsonPath, vbCritical
        Application.StatusBar = False
        Exit Sub
    End If

    Dim jsonFileName As String
    jsonFileName = Mid(jsonPath, InStrRev(jsonPath, "\") + 1)

    ' ---------- Buoc 3: Gui HTTP POST multipart/form-data ----------
    Dim responseBytes() As Byte
    Dim errMsg As String
    Dim httpStatus As Long

    If Not PostFileMultipart(SERVER_URL, "jsonfile", jsonFileName, jsonBytes, _
                              responseBytes, httpStatus, errMsg) Then
        Application.StatusBar = False
        MsgBox "Loi khi goi server:" & vbCrLf & errMsg, vbCritical, "Loi ket noi"
        Exit Sub
    End If

    If httpStatus <> 200 Then
        Application.StatusBar = False
        Dim bodyText As String
        bodyText = BytesToUtf8String(responseBytes)
        MsgBox "Server tra ve loi (HTTP " & httpStatus & "):" & vbCrLf & bodyText, _
               vbCritical, "Server bao loi"
        Exit Sub
    End If

    ' ---------- Buoc 4: Luu file docx nhan duoc vao thu muc tam ----------
    Dim outPath As String
    outPath = Environ$("TEMP") & "\" & _
              Left(jsonFileName, InStrRev(jsonFileName, ".") - 1) & "_converted.docx"

    If Not WriteBytesToFile(outPath, responseBytes) Then
        Application.StatusBar = False
        MsgBox "Khong ghi duoc file ket qua vao: " & outPath, vbCritical
        Exit Sub
    End If

    Application.StatusBar = False

    ' ---------- Buoc 5: Tu dong mo file docx vua nhan duoc ----------
    Documents.Open FileName:=outPath

    MsgBox "Chuyen doi thanh cong!" & vbCrLf & _
           "File da duoc mo: " & outPath, vbInformation, "Hoan tat"

End Sub


'=================================================================
' Helper: Mo hop thoai chon file, loc theo *.json
'=================================================================
Private Function ChooseJsonFile() As String
    Dim fd As FileDialog
    Set fd = Application.FileDialog(msoFileDialogFilePicker)

    fd.Title = "Chon file JSON ket qua OCR"
    fd.Filters.Clear
    fd.Filters.Add "File JSON", "*.json"
    fd.AllowMultiSelect = False

    If fd.Show = -1 Then
        ChooseJsonFile = fd.SelectedItems(1)
    Else
        ChooseJsonFile = ""
    End If
End Function


'=================================================================
' Helper: Doc toan bo noi dung 1 file thanh mang Byte
'=================================================================
Private Function ReadFileBytes(path As String, ByRef outBytes() As Byte) As Boolean
    On Error GoTo Fail
    Dim fnum As Integer
    fnum = FreeFile
    Dim fileLen As Long
    fileLen = FileLen(path)

    If fileLen = 0 Then
        ReDim outBytes(0)
        ReadFileBytes = True
        Exit Function
    End If

    ReDim outBytes(fileLen - 1)
    Open path For Binary Access Read As #fnum
    Get #fnum, , outBytes
    Close #fnum

    ReadFileBytes = True
    Exit Function

Fail:
    ReadFileBytes = False
End Function


'=================================================================
' Helper: Ghi mang Byte ra file
'=================================================================
Private Function WriteBytesToFile(path As String, data() As Byte) As Boolean
    On Error GoTo Fail
    Dim fnum As Integer
    fnum = FreeFile
    Open path For Binary Access Write As #fnum
    Put #fnum, , data
    Close #fnum
    WriteBytesToFile = True
    Exit Function

Fail:
    WriteBytesToFile = False
End Function


'=================================================================
' Helper: Doi mang byte (UTF-8) thanh String, dung khi doc noi
' dung loi tra ve tu server (thuong la JSON dang text)
'=================================================================
Private Function BytesToUtf8String(data() As Byte) As String
    On Error Resume Next
    Dim stm As Object
    Set stm = CreateObject("ADODB.Stream")
    stm.Type = 1  ' adTypeBinary
    stm.Open
    stm.Write data
    stm.Position = 0
    stm.Type = 2  ' adTypeText
    stm.Charset = "utf-8"
    BytesToUtf8String = stm.ReadText
    stm.Close
End Function


'=================================================================
' Helper CHINH: Gui 1 file len server bang HTTP POST voi noi dung
' dang multipart/form-data (giong nhu form <input type="file">
' tren web) - dung WinHttp, co san tren moi may Windows, khong can
' cai them thu vien nao.
'
' Tra ve True/False (thanh cong hay khong ve mang ket noi); httpStatus
' la ma HTTP tra ve (200 = OK); responseBytes la NOI DUNG tra ve (co
' the la file docx nhi phan, hoac JSON loi dang text).
'=================================================================
Private Function PostFileMultipart(url As String, fieldName As String, _
                                    fileName As String, fileBytes() As Byte, _
                                    ByRef responseBytes() As Byte, _
                                    ByRef httpStatus As Long, _
                                    ByRef errMsg As String) As Boolean

    On Error GoTo Fail

    Dim boundary As String
    boundary = "----VBAFormBoundary" & Format(Now, "yyyymmddhhmmss")

    ' --- Dung ADODB.Stream de ghep phan dau + noi dung file (binary)
    ' + phan cuoi cua multipart body, vi noi dung file la nhi phan
    ' nen khong the noi bang chuoi String binh thuong ---
    Dim headerText As String
    headerText = "--" & boundary & vbCrLf & _
                 "Content-Disposition: form-data; name=""" & fieldName & _
                 """; filename=""" & fileName & """" & vbCrLf & _
                 "Content-Type: application/json" & vbCrLf & vbCrLf

    Dim footerText As String
    footerText = vbCrLf & "--" & boundary & "--" & vbCrLf

    Dim bodyStream As Object
    Set bodyStream = CreateObject("ADODB.Stream")
    bodyStream.Type = 1 ' binary
    bodyStream.Open

    ' Ghi phan header (text) duoi dang binary UTF-8/ASCII
    AppendTextToBinaryStream bodyStream, headerText

    ' Ghi noi dung file JSON (da la byte roi, ghi thang)
    Dim fileStream As Object
    Set fileStream = CreateObject("ADODB.Stream")
    fileStream.Type = 1
    fileStream.Open
    fileStream.Write fileBytes
    fileStream.Position = 0
    bodyStream.Position = bodyStream.Size ' con tro ve cuoi de noi tiep
    ' ADODB.Stream khong co ham "append stream vao stream" truc tiep,
    ' nen doc tam ra bien roi ghi tiep:
    Dim fileVariant As Variant
    fileVariant = fileStream.Read
    fileStream.Close
    bodyStream.Write fileVariant

    ' Ghi phan footer
    AppendTextToBinaryStream bodyStream, footerText

    bodyStream.Position = 0
    Dim bodyVariant As Variant
    bodyVariant = bodyStream.Read
    bodyStream.Close

    ' --- Gui HTTP POST bang WinHttp ---
    Dim http As Object
    Set http = CreateObject("WinHttp.WinHttpRequest.5.1")

    http.Open "POST", url, False
    http.SetRequestHeader "Content-Type", "multipart/form-data; boundary=" & boundary
    http.SetTimeouts 10000, 10000, 30000, 120000  ' resolve, connect, send, receive (ms)

    http.Send bodyVariant

    httpStatus = http.Status

    Dim respStream As Object
    Set respStream = CreateObject("ADODB.Stream")
    respStream.Type = 1
    respStream.Open
    respStream.Write http.ResponseBody
    respStream.Position = 0

    Dim respSize As Long
    respSize = respStream.Size
    If respSize > 0 Then
        ' ADODB.Stream.Read() o che do binary (Type=1) tra ve truc tiep
        ' 1 mang Byte (boc trong Variant) - gan thang, KHONG dung vong
        ' lap AscB/MidB tung byte (rat cham voi file lon, vd docx nhieu
        ' anh co the toi vai tram nghin lan lap neu lam thu cong).
        responseBytes = respStream.Read(respSize)
    Else
        ReDim responseBytes(0)
    End If
    respStream.Close

    PostFileMultipart = True
    Exit Function

Fail:
    errMsg = Err.Description
    PostFileMultipart = False
End Function


'=================================================================
' Helper: Ghi 1 chuoi Text (se duoc encode UTF-8) vao 1
' ADODB.Stream dang binary da mo san, KHONG lam mat du lieu binary
' da co truoc do trong stream (dung stream tam roi noi vao).
'=================================================================
Private Sub AppendTextToBinaryStream(targetStream As Object, text As String)
    Dim tmpStream As Object
    Set tmpStream = CreateObject("ADODB.Stream")
    tmpStream.Type = 2 ' text
    tmpStream.Charset = "utf-8"
    tmpStream.Open
    tmpStream.WriteText text
    tmpStream.Position = 0

    ' Bo qua BOM 3 byte dau tien ma ADODB tu them khi Charset=utf-8
    tmpStream.Type = 1
    tmpStream.Position = 3

    Dim sz As Long
    sz = tmpStream.Size - 3
    If sz > 0 Then
        Dim v As Variant
        v = tmpStream.Read(sz)
        targetStream.Position = targetStream.Size
        targetStream.Write v
    End If
    tmpStream.Close
End Sub
