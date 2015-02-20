# Some of the clang related code from https://github.com/yasuyuky/autocomplete-clang
# Copyright (c) 2014 Yasuyuki YAMADA under MIT license

{Point, Range, BufferedProcess, TextEditor, CompositeDisposable} = require 'atom'
path = require 'path'
{existsSync} = require 'fs'

module.exports =
class ClangProvider
  id: 'autocomplete-clang-provider'
  selector: '.source.cpp, .source.c, .source.objc, .source.objcpp'
  providerblacklist:
    'autocomplete-plus-fuzzyprovider': '.source.cpp, .source.c, .source.objc, .source.objcpp'

  clangCommand: "clang"
  includePaths: [".", ".."]

  scopeSource:
    'source.cpp': 'c++'
    'source.c': 'c'
    'source.objc': 'objective-c'
    'source.objcpp': 'objective-c++'

  requestHandler: ({editor, scope, position}) ->
    language = LanguageUtil.getSourceScopeLang(@scopeSource, scope.getScopesArray())
    prefix = LanguageUtil.prefixAtPosition(editor, position)
    symbolPosition = LanguageUtil.nearestSymbolPosition(editor, position) ? position

    # console.log "'#{prefix}'", position, language
    if language?
      @codeCompletionAt(editor, symbolPosition.row, symbolPosition.column, language).then (suggestions) =>
        @filterForPrefix(suggestions, prefix)

  codeCompletionAt: (editor, row, column, language) ->
    command = @clangCommand
    args = @buildClangArgs(editor, row, column, language)
    options =
      cwd: path.dirname(editor.getPath())
      input: editor.getText()

    new Promise (resolve) =>
      allOutput = []
      stdout = (output) => allOutput.push(output)
      stderr = (output) => console.log output
      exit = (output) => resolve(@handleCompletionResult(allOutput.join('\n')))
      bufferedProcess = new BufferedProcess({command, args, options, stdout, stderr, exit})
      bufferedProcess.process.stdin.setEncoding = 'utf-8';
      bufferedProcess.process.stdin.write(editor.getText())
      bufferedProcess.process.stdin.end()

  filterForPrefix: (suggestions, prefix) ->
    res = []
    for suggestion in suggestions
      if suggestion.word.startsWith(prefix)
        suggestion.prefix = prefix
        res.push(suggestion)
    res

  lineRe: /COMPLETION: (.+) : (.+)$/
  returnTypeRe: /\[#([^#]+)#\]/ig
  argumentRe: /\<#([^#]+)#\>/ig
  convertCompletionLine: (s) ->
    match = s.match(@lineRe)
    if match?
      [line, completion, pattern] = match
      returnType = null
      patternNoType = pattern.replace @returnTypeRe, (match, type) ->
        returnType = type
        ''
      index = 0
      replacementSnippet = patternNoType.replace @argumentRe, (match, arg) ->
        index++
        "${#{index}:#{arg}}"

      {word: replacementSnippet, label: "returns #{returnType}"}

  handleCompletionResult: (result) ->
    outputLines = result.trim().split '\n'
    completions = (@convertCompletionLine(s) for s, i in outputLines when i < 1000)
    (completion for completion in completions when completion?)

  buildClangArgs: (editor, row, column, language)->
    # pch = [(atom.config.get "autocomplete-clang.pchFilePrefix"), language, "pch"].join '.'
    args = ["-fsyntax-only", "-x#{language}", "-Xclang"]
    location = "-:#{row + 1}:#{column + 1}"
    args.push("-code-completion-at=#{location}")

    pchPath = path.join(path.dirname(editor.getPath()), 'test.pch')
    args = args.concat ["-include-pch", pchPath] if existsSync pchPath
    # std = atom.config.get "autocomplete-clang.std.#{language}"
    # args = args.concat ["-std=#{std}"] if std
    args = args.concat("-I#{i}" for i in @includePaths)
    args.push("-")
    args





LanguageUtil =
  getSourceScopeLang: (scopeSource, scopesArray) ->
    for scope in scopesArray
      return scopeSource[scope] if scope of scopeSource
    null

  prefixAtPosition: (editor, position) ->
    line = editor.getTextInRange([[position.row, 0], position])

    end = line.length
    start = end - 1
    while start >= 0
      break unless /[\w0-9_-]/i.test(line[start])
      start--

    line.substring(start + 1, end)

  nearestSymbolPosition: (editor, position) ->
    methodCall = "\\[([\\w_-]+) (?:[\\w_-]+)?"
    propertyAccess = "([\\w_-]+)\\.(?:[\\w_-]+)?"
    regex = new RegExp("(?:#{propertyAccess})|(?:#{methodCall})$", 'i')

    line = editor.getTextInRange([[position.row, 0], position])
    matches = line.match(regex)
    if matches
      symbol = matches[1] ? matches[2]
      symbolColumn = matches[0].indexOf(symbol) + symbol.length + (line.length - matches[0].length)
      new Point(position.row, symbolColumn)
