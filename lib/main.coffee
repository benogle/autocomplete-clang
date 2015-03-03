ClangProvider = null

module.exports =
  activate: ->

  provide: ->
    ClangProvider ?= require('./clang-provider')
    new ClangProvider()
