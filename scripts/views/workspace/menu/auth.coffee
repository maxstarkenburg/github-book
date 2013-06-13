define [
  'jquery'
  'underscore'
  'backbone'
  'marionette'
  'session'
  'hbs!templates/workspace/menu/sign-in-out'
  'bootstrapTooltip'
], ($, _, Backbone, Marionette, session, signInOutTemplate) ->

  # Default Auth View
  # -------
  # The top-right of each page should have either:
  #
  # 1. a Sign-up/Login link if not logged in
  # 2. a logoff link with the current user name if logged in
  #
  # This view updates when the login state changes
  return Marionette.ItemView.extend
    template: signInOutTemplate
      authenticated: session.authenticated()
      user: session.user()

    events:
      'click #sign-out':      'signOut'
      'click #save-content':  'saveContent'

    initialize: () ->
      @listenTo(session, 'login logout', @render)

      # Bind a function to the window if the user tries to navigate away from this page
      beforeUnload = () =>
        return 'You have unsaved changes. Are you sure you want to leave this page?' if @hasChanged

      $(window).on 'beforeunload', beforeUnload

      # TODO: Listen for changes to content and enable Save button

    onRender: () ->
      @$el.html(@template) # FIXME: Why is marionnete not loading the template correctly
      # Enable tooltip
      @$el.find('#save-content').tooltip()

    # Clicking on the link will redirect to the logoff page
    # Before it does, update the model
    signOut: -> @model.signOut()

    # Save each model in sequence.
    # **FIXME:** This should be done in a commit batch
    saveContent: () ->
      return alert 'You need to Sign In (and make sure you can edit) before you can save changes' if not @model.get 'id'
      $save = @$el.find('#save-progress-modal')
      $saving     = $save.find('.saving')
      $alertError = $save.find('.alert-error')
      $successBar = $save.find('.progress > .bar.success')
      $errorBar   = $save.find('.progress > .bar.error')
      $label = $save.find('.label')

      total = @dirtyModels.length
      errorCount = 0
      finished = false

      recSave = =>
        $successBar.width(((total - @dirtyModels.length - errorCount) * 100 / total) + '%')
        $errorBar.width((  errorCount                                 * 100 / total) + '%')

        if @dirtyModels.length == 0
          if errorCount == 0
            finished = true
            $save.modal('hide')
          else
            $alertError.removeClass 'hide'

        else
          model = @dirtyModels.first()
          $label.text(model.get('title'))

          # Clear the changed bit since it is saved.
          #     delete model.changed
          #     saving = true; recSave()
          saving = model.save null,
              success: =>
                # Clear the dirty bit for the model
                model.set {_isDirty:false}
                recSave()
              error: -> errorCount += 1
          if not saving
            console.log "Skipping #{model.id} because it is not valid"
            recSave()

      $alertError.addClass('hide')
      $saving.removeClass('hide')
      $save.modal('show')
      recSave()

      # Only show the 'Saving...' alert box if the save takes longer than 2 seconds
      setTimeout(->
        if total and (not finished or errorCount)
          $save.modal('show')
          $alertError.removeClass('hide')
          $saving.addClass('hide')
      , 2000)