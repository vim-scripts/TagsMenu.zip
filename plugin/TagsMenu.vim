" Tags Menu for Vim: plugin to make a menu of tags in the current file
" Tagged Release Name: $Name: release-0_93 $
" Maintainer: Jay Dickon Glanville ($Author: J D Glanville $)
" Location: http://members.rogers.com/jayglanville/tagsmenu
" $Header: d:\\cvsroot/tagsmenu/workspace/TagsMenu.vim,v 1.16 2001/12/04 18:57:36 J D Glanville Exp $
" 
" See the accompaning documentation file for information on purpose,
" installation, requirements and available options.


" prevent multiple loadings ...
if exists("loaded_TagsMenu")
    finish
endif
let loaded_TagsMenu = 1

    
" ------------------------------------------------------------------------
" CONVIENCE MAPPINGS: mappings that I find useful.
" mapping to allow forced re-creation of the tags menu
nmap <unique> <leader>t :call <SID>TagsMenu_createMenu()<CR><CR>



" ------------------------------------------------------------------------
" AUTO COMMANDS: things to kick start the script
autocmd FileType * call <SID>TagsMenu_checkFileType()



" ------------------------------------------------------------------------
" OPTIONS: can be set to define behaviour
" The options are all wrapped in a "if !exists/endif" to prevent
" overwriting of the users options.

" this is the command to get tag info.
if !exists("g:TagsMenu_ctagsCommand")
    if &ft == 'perl'  " Force perl, in case it is embedded in a .bat file
        let g:TagsMenu_ctagsCommand = "ctags -f - --fields=+K --language-force=perl "
    else
        let g:TagsMenu_ctagsCommand = "ctags -f - --fields=+K "
    endif
endif
" Does this script produce debugging information?
if !exists("g:TagsMenu_debug")
    let g:TagsMenu_debug = 0
endif
" A list of characters that need to be escaped
if !exists("g:TagsMenu_excapeChars")
    let g:TagsMenu_escapeChars = "|"
endif
" Are the tags grouped and submenued by tag type?
if !exists("g:TagsMenu_groupByType")
    let g:TagsMenu_groupByType = 1
endif
" Does this script get automaticly run?
if !exists("g:TagsMenu_useAutoCommand")
    let g:TagsMenu_useAutoCommand = 1
endif
if !exists("g:TagsMenu_subgroupByFirstChar")
    let g:TagsMenu_subgroupByFirstChar = 0
endif



" ------------------------------------------------------------------------
" SCRIPT VARIABLES: constants and variables who's scope is limited to this
" script, but not limited to the inside of a method.

" The name of the menu
let s:menu_name = "Ta&gs"
" The name of the options menu
let s:option_menu_name = "&Options"
" command to turn on magic
let s:yesmagic = ""
" command to turn off magic
let s:nomagic = ""
" the name of the buffer to do the work in
let s:bufferName = "temporary_buffer"
" the name of the previous tag recognized
let s:previousTag = ""
" the count of the number of repeated tags
let s:repeatedTagCount = 0
" the list of currently recognized file types
let s:recognizedFiletypes = " asm awk c cpp sh cobol eiffel fortran java lisp make pascal perl php python rexx ruby scheme tcl vim cxx "



" This function is called everytime a filetype is set.  All it does is
" check the filetype setting, and if it is one of the filetypes recognized
" by ctags, then the TagsMenu_createMenu() function is called.  However, the
" g:TagsMenu_useAutoCommand == FALSE can veto the auto execution.
function! s:TagsMenu_checkFileType()
    if !g:TagsMenu_useAutoCommand
        return
    endif
    let s:currentFiletype = " " . &ft . " "
    call s:DebugVariable( "currentFiletype", s:currentFiletype )
    let s:filetypeFound = stridx( s:recognizedFiletypes, s:currentFiletype )
    if s:filetypeFound >= 0
        call s:TagsMenu_createMenu()
    endif
endfunction


" This is the function that actually calls ctags, parses the output, and
" creates the menus.
function! s:TagsMenu_createMenu() 

    call s:InitializeMenu()

    " execute the ctags command on the current file
    let command = g:TagsMenu_ctagsCommand . " " . "\"" . expand("%") . "\""
    call s:DebugVariable( "command", command )
    let output = system( command )
    call s:DebugVariable( "local variable 'output'", output )

    " create and switch to a new, temporary buffer.
    silent execute "badd " . s:bufferName
    silent execute "sbuffer " . s:bufferName

    " put the contents of local variable 'output' into a buffer
    silent put! =output

    " Set up the nomagic and magic variables
    if &magic
        let s:yesmagic = ":set magic<CR>"
        let s:nomagic = ":set nomagic<CR>"
    endif

    " loop over the entire file, parsing each line.  Apparently, this can be
    " done with a single command, but I can't remember it.
    let whilecount = 1
    let current = getline(whilecount)
    while current != ""

        call s:MakeMenuEntry( current )

        let whilecount = whilecount + 1
        let current = getline(whilecount)
    endwhile

    " if we're not debugging, then cleanup the temporary buffer
    if !g:TagsMenu_debug
        silent execute "bwipe! " . s:bufferName
    endif

endfunction



" ------------------------------------------------------------------------
" SCRIPT SCOPE FUNCTIONS: functions with a local script scope

" Initializes the menu by erasing the old one, creating a new one, and
" starting it off with a "Rebuild" command
function s:InitializeMenu()
    " first, lets remove the old menu
    execute "amenu " . s:menu_name . ".subname :echo\\ foo"
    execute "aunmenu " . s:menu_name

    " and now, add the top of the new menu
    execute "amenu " . s:menu_name . ".&Rebuild\\ Tags\\ Menu :call <SID>TagsMenu_createMenu()<CR><CR>"

    " First, the Options -> subgroup by first character menu item
    if g:TagsMenu_subgroupByFirstChar
        execute "amenu " . s:menu_name . "." . s:option_menu_name . ".Do\\ not\\ sub&group\\ by\\ first\\ character :call <SID>TagsMenu_optionSubgroupByFirstChar( 0 )<CR>"
    else
        execute "amenu " . s:menu_name . "." . s:option_menu_name . ".Sub&group\\ by\\ first\\ character :call <SID>TagsMenu_optionSubgroupByFirstChar( 1 )<CR>"
    endif

    " Next, the Options -> group by time menu item
    if g:TagsMenu_groupByType
        execute "amenu " . s:menu_name . "." . s:option_menu_name . ".Do\\ not\\ group\\ by\\ &type :call <SID>TagsMenu_optionGroupByType( 0 )<CR>"
    else
        execute "amenu " . s:menu_name . "." . s:option_menu_name . ".Group\\ by\\ &type :call <SID>TagsMenu_optionGroupByType( 1 )<CR>"
    endif

    execute "amenu " . s:menu_name . ".-SEP- :"
endfunction


" This function takes a string (assumidly a line from a tag file format) and
" parses out the pertanent information, and makes a tag entry in the tag
" menu.
function s:MakeMenuEntry(line)

    "lets make a few local variables to make things easy.
    let name = ""
    let type = ""
    let expression = ""

    " current is the current state of the line (hacked up as it is)
    let current = a:line

    " get the first token -- the name of the tag
    let index = match( current, "\t" )
    let name = strpart( current, 0, index )
    let current = strpart( current, index + 1, strlen( current ) )

    " is this an overloaded tag?
    if name == s:previousTag
        " it is overloaded ... augment the name
        let s:repeatedTagCount = s:repeatedTagCount + 1
        let name = name . "\\ (" . s:repeatedTagCount . ")"
    else
        let s:repeatedTagCount = 0
        let s:previousTag = name
    endif
    call s:DebugVaraibleRemainder( "name (of tag)", name, current )

    " get rid of the token that makes up the filename -- not used
    let index = match( current, "\t" )
    let current = strpart( current, index + 1, strlen( current ) )

    " get the expression to find the named tag (terminated by ;")
    let index = match( current, "\;\"" )
    let expression = strpart( current, 0, index )
    let current = strpart( current, index + 1, strlen( current ) )
    call s:DebugVaraibleRemainder( "expression (to find tag)", expression, current )
    if match( expression, "[0-9]" ) == 0
        " this expression is a line number not a pattern so prepend line number 
        " with : to make it an absolute line command not a relative one
        let expression = ":" . expression
    else
        " if you have nowrapscan on, then this will solve this by going back
        " to the top of the file first.
        let expression = ":0" . expression
    endif

    " strip out leading characters for level 1 to level 2 sparator
    let index = match( current, "\t" )
    let current = strpart( current, index + 1, strlen( current ) )
    call s:DebugVariable( "current", current )

    " get the first token from the level-2 portion of the tag.  This should
    " be the tag type
    let index = match( current, "\t" )
    if index == -1
        " there is no tabs in this portion, therefore, there is only
        " one token.  Take it.
        let index = strlen( current )
    endif
    let type = strpart( current, 0, index )
    let current = strpart( current, index + 1, strlen( current ) )
    call s:DebugVaraibleRemainder( "type (of tag)", type, current )

    " build the menu command
    let menu = "amenu " . s:menu_name 
    if g:TagsMenu_groupByType
      let menu = menu . ".&" . type
    endif
    if g:TagsMenu_subgroupByFirstChar
        let menu = menu . "." . strpart(name, 0, 1)
    endif
    let menu = menu . ".&" . name
    if !g:TagsMenu_groupByType
      let menu = menu . "<tab>" . type
    endif
    let menu = menu . " " . s:nomagic . expression . "<CR>" . s:yesmagic
    call s:DebugVariable( "Menu command ", menu )
    " escape some pesky characters
    execute escape( menu, g:TagsMenu_escapeChars )
endfunction


" Prints debugging information in the fprint format of "%s = %s (%s)",
" name, value, remainder
function! s:DebugVaraibleRemainder(name, value, remainder)
    if g:TagsMenu_debug
        echo a:name . " = " . a:value . " (" . a:remainder . ")"
    endif
endfunction


" Prints debugging information in the fprintf format of "%s = %s", name, value
function! s:DebugVariable(name, value)
    if g:TagsMenu_debug
        echo a:name . " = " . a:value
    endif
endfunction

" Changes the group-by-type option to turnOptionOn.  Primarily used by the
" Tags -> Options menu.
function s:TagsMenu_optionGroupByType( turnOptionOn )
    if a:turnOptionOn
        let g:TagsMenu_groupByType = 1
        call s:TagsMenu_createMenu()
        echo "Group by type = on for this session.  To set permanently, add \"let g:TagsMenu_groupByType = 1\" to your .vimrc."
    else
        let g:TagsMenu_groupByType = 0
        call s:TagsMenu_createMenu()
        echo "Group by type = off for this session.  To set permanently, add \"let g:TagsMenu_groupByType = 0\" to your .vimrc."
    endif
endfunction

" Changes the subgroup-by-first-char option to turnOptionOn.  Primarily used 
" by the Tags -> Options menu.
function s:TagsMenu_optionSubgroupByFirstChar( turnOptionOn )
    if a:turnOptionOn
        let g:TagsMenu_subgroupByFirstChar = 1
        call s:TagsMenu_createMenu()
        echo "Subgroup by first character = on for this session.  To set permanently, add \"let g:TagsMenu_subgroupByFirstChar = 1\" to your .vimrc."
    else
        let g:TagsMenu_subgroupByFirstChar = 0
        call s:TagsMenu_createMenu()
        echo "Subgroup by first character = off for this session.  To set permanently, add \"let g:TagsMenu_subgroupByFirstChar = 0\" to your .vimrc."
    endif
endfunction

