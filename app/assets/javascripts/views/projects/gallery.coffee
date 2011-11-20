#= require underscore
#= require backbone
#= require views/paginated
#= require views/projects/project
#= require models/projects_collection
#= require models/paginated_collection

#= require tmpls/projects/header
#= require tmpls/pagination

window.Pixie ||= {}
Pixie.Views ||= {}
Pixie.Views.Projects ||= {}

class Pixie.Views.Projects.Gallery extends Pixie.Views.Paginated
  el: ".projects"

  initialize: ->
    self = @

    # merge the superclass paging related events
    @events = _.extend(@pageEvents, @events)
    @delegateEvents()

    @collection = new Pixie.Models.ProjectsCollection

    @collection.bind 'fetching', ->
      $(self.el).find('.spinner').show()

    @collection.bind 'reset', (collection) ->
      $(self.el).find('.header').remove()
      $(self.el).find('.pagination').remove()
      $(self.el).append $.tmpl("projects/header", self.collection.pageInfo())

      $(self.el).find('.project').remove()
      $(self.el).find('.spinner').hide()
      collection.each(self.addProject)

      self.updatePagination()

  addProject: (project) =>
    view = new Pixie.Views.Projects.Project({ model: project, collection: @collection })
    $(@el).append(view.render().el)

  updatePagination: =>
    $(@el).find('.pagination').html $.tmpl('pagination', @collection.pageInfo())


