ClangProvider = null

module.exports =
  provider: null
  ready: false

  activate: ->
    @ready = true

  deactivate: ->
    @provider = null

  provide: ->
    ClangProvider ?= require('./clang-provider')
    @provider ?= new ClangProvider()
    {@provider}
