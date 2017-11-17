window.RactiveNetTangoBlocksTabWidget = Ractive.extend({
  data: -> {
      code:          undefined,
      blockDefsJson: undefined,
      isStale:       false,
      tangoCode:     undefined
    }

  setup: (thisBoi, workspaceDefinition) ->
    ntCanvas = document.getElementById('nt-workspace')
    if(ntCanvas)
      # Setting width/height like this is not great, but `NetTango.init()` seems to hardcode values (doubles in size each call)
      ntCanvas.height = 800
      ntCanvas.width = 800
      ntCanvas.style.height = '800px'
      ntCanvas.style.width = '800px'
      NetTango.init('nt-workspace', workspaceDefinition)
      NetTango.addProgramChangedCallback('nt-workspace', (canvasId) ->
        newTangoCode = NetTango.exportCode(canvasId, 'NetLogo').replace('; --- NETTANGO BEGIN ---', '').replace('; --- NETTANGO END ---', '')
        thisBoi.fire('tango-set-code', newTangoCode.trim())
      )

  oncomplete: ->
    workspaceDefinition = JSON.parse(@get('blockDefsJson'))
    this.setup(this, workspaceDefinition)

    thisBoi = this
    thisBoi.on('tango-compile', () ->
      this.set('isStale', false)
      newProcedures = thisBoi.get('tangoCode').split(/(?:^|\n)(?=to [\w-]+)/)
      namesToProcedures = newProcedures.map((x) => [x.match(/^to ([\w-]+)/)[1], x])
      updateCode = (code, acc) ->
         name      = acc[0]
         procedure = acc[1]
         code.replace(new RegExp("((?:^|\n); NETTANGO START " + name + "\n)([^]*)(\n; NETTANGO END " + name + ")"), "$1" + procedure + "$3")
      newCode = namesToProcedures.reduce(updateCode, thisBoi.get('code'))
      this.set('code', newCode)
      this.fire('recompile')
    )

    thisBoi.on('tango-set-code', (_, code) ->
      if (code != this.get('tangoCode'))
        this.set('isStale', true)
        this.set('tangoCode', code)
      return
    )

    @parent.on('*.tango-show-toggle', (_, show) ->
      ntContent = document.getElementById('nt-content')
      if (ntContent)
        ntContent.style.display = if show then 'flex' else 'none'
    )

    @parent.on('*.tango-refresh', (_, blocks) ->
      thisBoi.set('blockDefsJson', blocks)
      thisBoi.setup(thisBoi, JSON.parse(blocks))
      thisBoi.set('tangoCode', NetTango.exportCode('nt-workspace', 'NetLogo'))
      thisBoi.set('isStale', true)
    )

    return

  template:
    """
    <div id='nt-content' class='netlogo-tab-content' intro='grow:{disable:"info-toggle"}' outro='shrink:{disable:"info-toggle"}' style="display: none; flex-direction: column; align-items: center;">
      <button class="netlogo-widget netlogo-ugly-button netlogo-recompilation-button" on-click="tango-compile" {{# !isStale }}disabled{{ / }} >Recompile Blocks</button>
      <div id="nt-container" style="margin-bottom: 15px;">
        <canvas id="nt-workspace" width="400" height="400" style="background: #e9e5cd;"></canvas>
      </div>
    </div>
    """
})

window.RactiveNetTangoDefsTabWidget = Ractive.extend({
  data: -> {
    isStale: false
  }

  oncomplete: ->
    blockDefsEditor = CodeMirror(@find('#nettango-block-defs-editor'), {
      value:          @get('blockDefsJson') ? '{ "blocks": [ ] }',
      tabSize:        2,
      indentUnit:     2,
      lineNumbers:    true,
      mode:           'application/json',#{ name: "javascript", json: true },
      theme:          'netlogo-default',
      editing:        true,#@get('editing'),
      viewportMargin: Infinity
      lineWrapping:   true
    })

    blockDefsEditor.on('change', =>
      @set('blockDefsJson', blockDefsEditor.getValue())
      @set('isStale', true)
    )

    this.on('tango-refresh', (_, blockDefsJson) ->
      # console.log("Fired refresh: #{JSON.parse(blockDefsJson)}")
      @set('isStale', false)
    )

  template:
    """
    <div class='netlogo-tab-content netlogo-code-container' intro='grow:{disable:"info-toggle"}' outro='shrink:{disable:"info-toggle"}' style="display: flex; flex-direction: column; align-items: center;">
      <button class="netlogo-widget netlogo-ugly-button netlogo-recompilation-button" on-click="['tango-refresh', blockDefsJson]" {{# !isStale }}disabled{{ / }} >Refresh Blocks</button>
      <div id='nettango-block-defs-editor' class='netlogo-code' style="width:100%;"></div>
    </div>
    """
})
