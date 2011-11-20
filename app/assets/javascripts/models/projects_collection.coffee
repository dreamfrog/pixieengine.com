#= require underscore
#= require backbone
#= require models/paginated_collection
#= require models/project

window.Pixie ||= {}
Pixie.Models ||= {}

class Pixie.Models.ProjectsCollection extends Pixie.Models.PaginatedCollection
  model: Pixie.Models.Project

  parse: (data) =>
    Pixie.Models.PaginatedCollection.prototype.parse.call(@, data)

  url: ->
    '/people/projects'

