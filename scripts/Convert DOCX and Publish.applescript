property appTitle : "Convert DOCX & Publish"
property publisherScript : "/Users/windsor/Github/JFWooten4/documents/scripts/convert-docx-and-publish.sh"

on run
	try
		set selectedFile to choose file with prompt "Choose a Word document to convert, commit, and push:" of type {"org.openxmlformats.wordprocessingml.document", "docx"}
		my processDocument(selectedFile)
	on error number -128
		-- The user cancelled the picker.
	end try
end run

on open droppedItems
	if (count of droppedItems) is not 1 then
		display alert appTitle message "Drop exactly one .docx file onto the app." as warning
		return
	end if
	my processDocument(item 1 of droppedItems)
end open

on processDocument(documentAlias)
	set documentPath to POSIX path of documentAlias
	try
		set resultMessage to do shell script quoted form of publisherScript & space & quoted form of documentPath
		display notification resultMessage with title appTitle
		display dialog resultMessage with title appTitle buttons {"OK"} default button "OK" with icon note
	on error errorMessage number errorNumber
		display alert appTitle message errorMessage as critical
	end try
end processDocument
