Option Explicit
Public mDictionary() As Variant ' Global Array!
Public mPostings() As Variant
Public mAccumulator() As Variant

Sub IndexCollection()
    
    Application.ScreenUpdating = False
    
    'Close 'DEBUG - REMOVE LATER
    
    ReDim mDictionary(1, 0) As Variant 'Indicates word (0) and df (1)
    ReDim mPostings(2, 0) As Variant 'Indicates word (0), file (1), and tf (2)
    
    Sheets("Postings").Cells.Clear
    Sheets("Dictionary").Cells.Clear
    
    Dim Directory As String: Directory = ThisWorkbook.Path & "\Collection\"
    Dim f As String: f = Dir(Directory)
    Dim StartHere As Range
    Set StartHere = Range("A1")
    Dim r As Integer: r = 0
        
    Do While f <> "" 'Loop through docs
        Open Directory & f For Input As #1
       
        Dim m As Integer 'Track total number of Docs (M)
        m = m + 1
    
        Do Until EOF(1) 'Read document
            Dim data As String
            Line Input #1, data 'Split doc into lines
            Dim WordArray As Variant
            WordArray = Split(data, " ") 'Split line into words
            Dim i As Integer
            
            For i = LBound(WordArray) To UBound(WordArray) 'Loop through words
                Dim j As Integer
                Dim TempWord As String: TempWord = ""
                
                'Stemming------------------------------
                'Call Module1.porterAlgorithm(WordArray(i))
                '--------------------------------------
                
                For j = 1 To Len(WordArray(i)) 'Remove punctuation + turn lowercase
                    If LCase(Mid(WordArray(i), j, 1)) Like "[a-z0-9]" Then
                        TempWord = TempWord & LCase(Mid(WordArray(i), j, 1))
                    End If
                Next j
                WordArray(i) = TempWord

                Call UpdatePostingsAndDict(LCase(WordArray(i)), f)
            Next i
        Loop
        Close #1
        f = Dir()
    Loop
    
    Call UpdateTF
    Call LogIDf(mDictionary, m)
    Call BubbleSortDict(mDictionary)
    Call BubbleSortPost(mPostings)
    Call writePostings(mPostings)
    Call writeDict(mDictionary)
    
    Application.ScreenUpdating = True
    
End Sub
    
    '===========================PART 2===========================
Public Sub ProcessQuery()
    'If UBound(mDictionary, 2) = 0 Then  Note: The method of Redim these arrays when workbook open did not work
                                         'in the end sometime it work sometime it doesn't, it's too inconsitent
                                         'I could not fix the problem. So have to run index everytime.
        Call IndexCollection
    'End If
    
    Dim InputQ As String: InputQ = ActiveSheet.OLEObjects("TextBox1").Object.Text 'Get query terms from textbox
    Dim QueryAry() As Variant
    ReDim QueryAry(3, 0) As Variant '(0)= QTerm (1)= query Normalized tf (2)= idf (3)= tf*idf
        
        If InputQ = "" Then
            MsgBox "Please think of something to search."
            Exit Sub
        End If

        Dim QTerm As Variant
        QTerm = Split(InputQ, " ") 'Split line into words + other clean ups too! (same as dict terms)
        
        Dim i As Integer
        For i = LBound(QTerm) To UBound(QTerm) 'Loop through query terms
                Dim j As Integer
                Dim TempTerm As String: TempTerm = ""

                'Stemming------------------------------
                'Call Module1.porterAlgorithm(WordArray(i))
                '--------------------------------------
                
                For j = 1 To Len(QTerm(i)) 'Remove punctuation
                    If LCase(Mid(QTerm(i), j, 1)) Like "[a-z0-9]" Then
                        TempTerm = TempTerm & LCase(Mid(QTerm(i), j, 1))
                    End If
                Next j

                ReDim Preserve QueryAry(3, UBound(QueryAry, 2) + 1)
                QueryAry(0, i) = TempTerm
                Dim Dindex As Integer: Dindex = 0 '(k)
                Dim DictFound As Boolean: DictFound = False
    
                    QueryAry(1, i) = 1 / Sqr(UBound(QTerm) + 1) '+1 'Calculate query tf, NEED TO MAKE IT 2!
                    For Dindex = 1 To UBound(mDictionary, 2)
                        If TempTerm = mDictionary(0, Dindex) Then 'Search in Dictionary
                            DictFound = True
                            QueryAry(2, i) = mDictionary(1, Dindex) 'Collect its idf (qTerm, idf, tf*idf) in QueryAry
                            QueryAry(3, i) = QueryAry(1, i) * QueryAry(2, i) 'tf*idf query vector
                        End If
                    Next Dindex

                        If Not DictFound Then   'Problem found: Extra space typed in the query will result "No match found". - need fix
                            MsgBox "No match found."
                            Exit For
                        End If
        Next i
        
        Call SortQueryAry(QueryAry)
        Call UpdateAccumulator(QueryAry)

End Sub ' Fit all Part 2 in this Sub
Sub UpdateAccumulator(QueryArr As Variant)
       
        ReDim mAccumulator(1, 0) As Variant
        Dim AMax As Integer
        Dim QTerm As String: QTerm = QueryArr(0, 0)
        Dim PostIndex As Integer: PostIndex = 0
        
        'The first query term -----------------------------------------------

        'Do '(loop through postings) Abandon. I couldn't make it work using this method.
        
        For PostIndex = 1 To UBound(mPostings, 2)
            If QTerm = mPostings(0, PostIndex) Then 'the token column
                ReDim Preserve mAccumulator(1, AMax + 1)
                mAccumulator(0, AMax + 1) = mPostings(1, PostIndex) 'doc name
                mAccumulator(1, AMax + 1) = mPostings(2, PostIndex) * QueryArr(3, 1) 'tf * tf*idf (weight)
                AMax = UBound(mAccumulator, 2)
                
            End If
        Next PostIndex
        'The remaining of the query terms -----------------------------------------------
                Dim AccumulatorCheck As Variant
                Dim DocId As String
                Dim Qindex As Integer
                For Qindex = 1 To UBound(QueryArr, 2)
                    QTerm = QueryArr(0, Qindex)
                    
                    For PostIndex = 0 To UBound(mPostings, 2)
                    If QTerm = mPostings(0, PostIndex) Then 'the token column
                    DocId = mPostings(1, PostIndex)
                    AccumulatorCheck = CheckAccumulator(DocId) 'Problem found: if the 2nd sorted QTerm (less weight) is found in Docs that doesn't intersect with the first QTerm, those Docs will never be added to the Accumulator..
                        If AccumulatorCheck <> Null Then
                            mAccumulator(1, AccumulatorCheck) = mAccumulator(1, AccumulatorCheck) + _
                                    QueryArr(3, Qindex) * mPostings(2, PostIndex)
                        End If
                    End If
                    Next PostIndex
                Next Qindex
            
        Call SortAccumulator(mAccumulator)

        'Loop Until NoMoreDocs

    
    'Print Search Results ----------------------------------------------
        Dim AIndex As Integer: AIndex = 0
        Dim outputArea As Range
        Set outputArea = Range("C10", "D10")
        
        Sheets("Search").Cells.Clear
        If UBound(mAccumulator, 2) < 10 Then
            For AIndex = 0 To AMax
                Range("C10").Offset(AIndex - 1, 0) = mAccumulator(0, AIndex)
                Range("D10").Offset(AIndex - 1, 0) = mAccumulator(1, AIndex)
            Next AIndex
        Else
            For AIndex = 1 To 10
                Range("C10").Offset(AIndex - 1, 0) = mAccumulator(0, AIndex)
                Range("D10").Offset(AIndex - 1, 0) = mAccumulator(1, AIndex)
            Next AIndex
        End If
        
End Sub
Private Function CheckAccumulator(DocId As String) As Variant
'returns Null if not found, i position otherwise

    CheckAccumulator = Null
    Dim i As Integer: i = 0
    Dim DocIdFound As Boolean: DocIdFound = False
    Do
        If DocId = mAccumulator(0, i) Then
            DocIdFound = True
        Else
            i = i + 1
        End If
    Loop While Not DocIdFound And _
                i <= UBound(mAccumulator, 2)
    
    If DocIdFound Then
        CheckAccumulator = i
    End If
  
End Function

Sub UpdatePostingsAndDict(Token As String, FileName As String) ' to create tf
    'POSTINGS
    Dim i As Integer
    Dim PostFound As Boolean: PostFound = False
    For i = 1 To UBound(mPostings, 2)
        If Token = mPostings(0, i) And FileName = mPostings(1, i) Then
            PostFound = True
            mPostings(2, i) = mPostings(2, i) + 1
            Exit For
        End If
    Next
    If Not PostFound And Len(Token) > 0 Then    '*have to filter out those blank spaces! Doesn't matter actually..
        ReDim Preserve mPostings(2, UBound(mPostings, 2) + 1) 'tf increase by 1
        mPostings(0, UBound(mPostings, 2)) = Token
        mPostings(1, UBound(mPostings, 2)) = FileName
        mPostings(2, UBound(mPostings, 2)) = 1
        'mPostings has to come out as an array with all words of the doc
        '==============================================
        'DICTIONARY
        Dim DictFound As Boolean: DictFound = False
        For i = 0 To UBound(mDictionary, 2)
            If Token = mDictionary(0, i) Then
                DictFound = True
                mDictionary(1, i) = mDictionary(1, i) + 1
                Exit For
            End If
        Next
    
        If Not DictFound Then
            ReDim Preserve mDictionary(1, UBound(mDictionary, 2) + 1) 'df increase by 1
            mDictionary(0, UBound(mDictionary, 2)) = Token
            mDictionary(1, UBound(mDictionary, 2)) = 1
       
        End If
    End If
    
End Sub
Sub writePostings(Ary As Variant)
    Dim i As Integer
    Dim r As Integer
    i = 0
    r = 1
    
    For i = 1 To UBound(Ary, 2)
        Worksheets("Postings").Cells(r, 1) = Ary(0, i) 'Assign word to sheet
        Worksheets("Postings").Cells(r, 2) = Ary(1, i) 'Assign filename to sheet
        Worksheets("Postings").Cells(r, 3) = Ary(2, i) 'Assign tf to sheet
        r = r + 1
    Next i
End Sub
Sub writeDict(Ary As Variant)
    Dim i As Integer
    Dim r As Integer
    i = 0
    r = 1
    
    For i = 1 To UBound(Ary, 2)
        Worksheets("Dictionary").Cells(r, 1) = Ary(0, i) 'Assign word to sheet
        Worksheets("Dictionary").Cells(r, 2) = Ary(1, i) 'Assign df to sheet
    r = r + 1
    Next i
End Sub

Private Sub LogIDf(DictAry As Variant, m As Integer)

    Dim i As Integer
    For i = 1 To UBound(DictAry, 2) 'try to skip the first blank space
        DictAry(1, i) = Log(m / DictAry(1, i))
    Next i
    
End Sub

Private Sub UpdateTF() 'Normalizing TF - Assumes postings are sorted by file
    Dim lastFile As String
    lastFile = mPostings(1, 1)
    
    Dim SumSquares As Long
    Dim i As Integer
    For i = 1 To UBound(mPostings, 2)
        If lastFile = mPostings(1, i) Then
            SumSquares = SumSquares + WorksheetFunction.Power(mPostings(2, i), 2) 'Bug here! Type mismatched
        Else
            Call NormFileTfs(lastFile, i - 1, SumSquares)
            SumSquares = 0
        End If
        lastFile = mPostings(1, i)
    Next
    Call NormFileTfs(lastFile, UBound(mPostings, 2), SumSquares)
End Sub
Private Sub NormFileTfs(FileName As String, FileLastSlot As Integer, SumSquares As Long)
    Dim hypo As Double
    hypo = Sqr(SumSquares)
    
    Dim j As Integer: j = FileLastSlot
    Do While mPostings(1, j) = FileName
        mPostings(2, j) = mPostings(2, j) / hypo
        j = j - 1
    Loop
End Sub

Sub BubbleSortDict(List() As Variant)
    Dim i As Long, j As Long
    Dim temp As String, temp1 As Double

  For i = 0 To UBound(List, 2) - 1
        For j = i + 1 To UBound(List, 2)
            If List(0, i) > List(0, j) Then
                temp = List(0, j)
                temp1 = List(1, j)
                
                List(0, j) = List(0, i)
                List(1, j) = List(1, i)
                
                List(0, i) = temp
                List(1, i) = temp1
   
            End If
        Next j
    Next i
End Sub

Sub BubbleSortPost(List() As Variant)
    Dim i As Long, j As Long
    Dim temp As String, temp1 As String, temp2 As Double

  For i = 0 To UBound(List, 2) - 1
        For j = i + 1 To UBound(List, 2)
            If List(1, i) > List(1, j) Then
                temp = List(0, j)
                temp1 = List(1, j)
                temp2 = List(2, j)
                
                List(0, j) = List(0, i)
                List(1, j) = List(1, i)
                List(2, j) = List(2, i)
                
                List(0, i) = temp
                List(1, i) = temp1
                List(2, i) = temp2
   
            End If
        Next j
    Next i
End Sub
Sub SortQueryAry(List() As Variant)
    Dim i As Long, j As Long
    Dim temp As String, temp1 As Double, temp2 As Double, temp3 As Double

  For i = 0 To UBound(List, 2) - 1
        For j = i + 1 To UBound(List, 2)
            If List(2, i) < List(2, j) Then
                temp = List(0, j)
                temp1 = List(1, j)
                temp2 = List(2, j)
                temp3 = List(3, j)
                
                List(0, j) = List(0, i)
                List(1, j) = List(1, i)
                List(2, j) = List(2, i)
                List(3, j) = List(3, i)
                
                List(0, i) = temp
                List(1, i) = temp1
                List(2, i) = temp2
                List(3, i) = temp3
   
            End If
        Next j
    Next i
End Sub

Sub SortAccumulator(List() As Variant)
    Dim i As Long, j As Long
    Dim temp As String, temp1 As Double

  For i = 0 To UBound(List, 2) - 1
        For j = i + 1 To UBound(List, 2)
            If List(1, i) < List(1, j) Then
                temp = List(0, j)
                temp1 = List(1, j)
                
                List(0, j) = List(0, i)
                List(1, j) = List(1, i)
                
                List(0, i) = temp
                List(1, i) = temp1
   
            End If
        Next j
    Next i
End Sub

'Dec 11, 2015




