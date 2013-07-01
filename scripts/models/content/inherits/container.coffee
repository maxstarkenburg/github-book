define [
  'jquery'
  'underscore'
  'backbone'
  'cs!models/content/inherits/base'
], ($, _, Backbone, BaseModel) ->

  # Backbone Collection used to store a container's contents
  Container = Backbone.Collection.extend
    findMatch: (model) ->
      return _.find @titles, (obj) ->
        return model.id is obj.id or model.cid is obj.id

    getTitle: (model) ->
      if model.unique
        return model.get('title')

      return @findMatch(model)?.title or model.get('title')

    setTitle: (model, title) ->
      if model.unique
        model.set('title', title)
      else
        match = @findMatch(model)

        if match
          match.title = title
        else
          @titles.push
            id: model.id or model.cid
            mediaType: model.mediaType
            title: title

        model.trigger('change')

      return @

  # Helper function to parse html-encoded data
  parseHTML = (html) ->
    if typeof html isnt 'string' then return []

    results = []

    $(html).find('> ol').find('> li').each (index, el) ->
      $el = $(el)
      $node = $el.children().eq(0)

      if $node.is('a')
        id = $node.attr('href')
        title = $node.text()

      # Only remember the title if it's overridden
      if not title or $node.hasClass('autogenerated-text')
        results.push({id: id})
      else
        results.push({id: id, title: title})

    return results

  return BaseModel.extend
    mediaType: 'application/vnd.org.cnx.folder'
    accept: []
    unique: true
    branch: true
    expanded: false
    promise: () -> return @_deferred.promise()

    toJSON: () ->
      json = BaseModel::toJSON.apply(@, arguments)

      contents = @getChildren() or {}

      json.contents = []
      _.each contents.models, (item) ->
        obj = {}
        title = contents.getTitle?(item) or contents.get 'title'
        if item.id then obj.id = item.id
        if title then obj.title = title

        json.contents.push(obj)

      return json

    accepts: (mediaType) ->
      if (typeof mediaType is 'string')
        return _.indexOf(@accept, mediaType) is not -1

      return @accept

    initialize: (attrs) ->
      # TODO: Make this a private variable once this class actually becomes a coffeescript class

      if @isNew()
        # If this is a new model then `.load()` should resolve immediately
        @_loading = $.Deferred().resolve()

        # Ensure the container always has a contents
        @set('contents', new Container())

    load: () ->
      if not @_loading
        @_loading = @fetch()
        # Weird: wait for the Workspace to finish loading for some reason
        # so, make another promise
        @_loading = @_loading.then () =>
      @_loading


    getChildren: () ->
      @get('contents')

    addChild: (model, at=0) ->
      children = @getChildren()

      # If `model` is already in `@getChildren()` then we are reordering.
      # By removing the model, we need to adjust the index where it will be
      # added.
      if children.contains(model)
        if children.indexOf(model) < at
          at = at - 1
        children.remove(model)

      children.add(model, {at:at})

    parse: (json) ->
      if json.contents
        if _.isArray(json.contents)
          json.contents = new Container(json.contents)
        else
          json.contents = parseHTML(json.contents)

      else if json.body
        json.contents = json.body
      else throw 'BUG: Container must contain either a contents or a body'

      # Toss the contents into the workspace
      # Weird odd that it's being done in parse
      require ['cs!collections/content'], (content) =>
        content.load().done () =>
          _.each contents, (item) =>
            @add(content.get({id: item.id}), options)
          # TODO: Why does loading have to wait until the workspace loads fully
          # Seems like an odd dependency (the code is weird too)
          @_loading.resolve(@)


    # Change the content view when editing this
    contentView: (callback) ->
      require ['cs!views/workspace/content/search-results'], (View) =>
        view = new View({collection: @getChildren()})
        callback(view)

    # Change the sidebar view when editing this
    sidebarView: (callback) ->
      require ['cs!views/workspace/sidebar/toc'], (View) =>
        view = new View
          collection: @getChildren()
          model: @
        callback(view)
