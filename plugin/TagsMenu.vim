" Tags Menu for Vim: plugin to make a menu of tags in the current file
" Last Modified: 7 August 2001
" Maintainer: Jay Dickon Glanville <jayglanville@home.com>
" Location: http://members.home.net/jayglanville/tagsmenu/TagsMenu.html.
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

" this is the command to get tag info.  If you don't have version 4.0.2 or
" greater of ctags, then modify this variable to remove the "--kind-long=yes" 
let g:TagsMenu_ctagsCommand = "ctags -f - --fields=+K "
" Does this script produce debugging information?
let g:TagsMenu_debug = 0
" A list of characters that need to be escaped
let g:TagsMenu_escapeChars = "|"
" Are the tags grouped and submenued by tag type?
let g:TagsMenu_groupByType = 1
" Does this script get automaticly run?
let g:TagsMenu_useAutoCommand = 1



" ------------------------------------------------------------------------
" SCRIPT VARIABLES: constants and variables who's scope is limited to this
" script, but not limited to the inside of a method.

" The name of the menu
let s:menu_name = "Ta&gs"
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



" This function is called everytime a filetype is set.  All it does is
" check the filetype setting, and if it is one of the filetypes recognized
" by ctags, then the TagsMenu_createMenu() function is called.  However, the
" g:TagsMenu_useAutoCommand == FALSE can veto the auto execution.
function! s:TagsMenu_checkFileType()
    if !g:TagsMenu_useAutoCommand
        return
    endif
    call s:DebugVariable( "filetype", &ft )
    " sorry about the bad form of this if statement, but apparently, the
    " expression needs to be terminated by an EOL. (I could use if/elseif...)
    if  (&ft == "asm") || (&ft == "awk") || (&ft == "c") || (&ft == "cpp") || (&ft == "sh") || (&ft == "cobol") || (&ft == "eiffel") || (&ft == "fortran") || (&ft == "java") || (&ft == "lisp") || (&ft == "make") || (&ft == "pascal") || (&ft == "perl") || (&ft == "php") || (&ft == "python") || (&ft == "rexx") || (&ft == "ruby") || (&ft == "scheme") || (&ft == "tcl") || (&ft == "vim") || (&ft == "cxx")
        call s:TagsMenu_createMenu()
    endif
endfunction


" This is the function that actually calls ctags, parses the output, and
" creates the menus.
function! s:TagsMenu_createMenu() 

    call s:InitializeMenu()

    " execute the ctags command on the current file
    let command = g:TagsMenu_ctagsCommand . " " . expand("%")
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
