#= require sha1
#= require base64

namespace "Github", (Github) ->
  API_ROOT = "https://api.github.com"

  Client = (token) ->
    self =
      apiCall: (path, data, callback, type="POST") ->
        if typeof data is "function"
          callback = data
          data = {}

        url = "#{API_ROOT}#{path}"

        console.log "GITHUB #{type}: ", url, data

        data = JSON.stringify(data) unless type is "GET"

        $.ajax
          contentType: 'application/json'
          data: data
          dataType: 'json'
          success: (data) ->
            console.log "GITHUB RESPONSE: ", data
            callback(data)
          error: (data) ->
            console.log(data)
          type: type
          url: "#{url}?access_token=#{token}"

      get: (path, data, callback) ->
        self.apiCall(path, data, callback, "GET")

      patch: (path, data, callback) ->
        self.apiCall(path, data, callback, "PATCH")

      post: (path, data, callback) ->
        self.apiCall(path, data, callback)

    return self

  Repo = (client, user, repo) ->
    urlBase = "/repos/#{user}/#{repo}"

    self =
      tree: (sha="master", callback) ->
        url = "/repos/#{user}/#{repo}/git/trees/#{sha}"

        client.get url,
          recursive: 1
        , (data) =>
          callback?(data.tree)

      getFile: ({sha, path, callback}) ->
        self.tree sha, (tree) ->
          fileInfo = tree.select (fileData) ->
            fileData.path is path
          .first()

          if fileInfo
            sha = fileInfo.sha

            self.getBlob sha, ({content, encoding}) ->
              if encoding is "base64"
                content = Base64.decode(content)

              # Verify
              if sha == CryptoJS.SHA1("blob #{content.length}\0#{content}").toString()
                log("SHA1 VERIFIED")
                callback(content)
              else
                log("SHA1 FAILED VERIFICATION")

          else
            log "FILE #{path} NOT FOUND AT #{url}"

      getBlob: (sha, callback) ->
        client.get "#{urlBase}/git/blobs/#{sha}", callback

      createBlob: (data, callback) ->
        client.post "#{urlBase}/git/blobs", data, callback

      createTree: (data, callback) ->
        url = "#{urlBase}/git/trees"

        client.post url, data, callback

      getCommit: (sha, callback) ->
        url = "#{urlBase}/git/commits/#{sha}"

        client.get url, callback

      getLatestCommitAt: (ref, callback) ->
        self.getReference ref, ({object}) ->
          self.getCommit object.sha, callback

      getReference: (ref, callback) ->
        url = "#{urlBase}/git/refs/heads/#{ref}"

        client.get url, callback

      updateReference: (ref, sha, callback) ->
        url = "#{urlBase}/git/refs/heads/#{ref}"

        client.patch url,
          sha: sha
        , callback

      createCommit: (data, callback) ->
        url = "#{urlBase}/git/commits"

        client.post url, data, callback

      commit: () ->

      initialCommit: () ->
        # Not possible through API right now
        # One option is to use the collaborators API
        # to add a collaborator then hit our server to
        # have it set up the initial commit.

      # Make sure all files are blobs in the repo
      ingestFiles: (files) ->
        for file in files
          self.createBlob file, (data) ->
            # TODO: Verify SHA

            # Update SHA
            file.set data

    return self

  Github.Client = (token) ->
    client = Client(token)

    self =
      Repo: (user, repo) ->
        Repo(client, user, repo)

      createRepo: (data, callback) ->
        client.post("/user/repos", data, callback)

      forkRepo: (user, repo, callback) ->
        client.post "/repos/#{user}/#{repo}/forks", callback

      getFile: ({user, repo, sha, callback, path}) ->
        self.Repo(user, repo).getFile
          sha: sha
          path: path
          callback: callback

    Object.extend(self, client)

    return self

  # Some testing methods
  Github.loadRepoInTree = (user="STRd6", repo="PixieDemo") ->
    client = Github.Client(githubToken)
    repo = client.Repo(user, repo)

    repo.tree "pixie", (tree) ->
      fileTree = new BoneTree.Views.Tree

      # Add each file
      for file in tree
        continue if file.type is "tree"
        fileTree.add(file.path, file)

      $('.sidebar').empty()
      $('.sidebar').append(fileTree.render().$el)

      fileTree.bind 'openFile', (file) ->
        openFile(file)

      # Populate files in tree with actual contents
      fileTree.toArray().select (node) ->
        node.isFile()
      .each (file) ->
        url = file.get "url"
        client.fileContents url, (contents) ->
          file.set
            contents: contents

      window.tree = fileTree

  Github.commit = (user="STRd6", repo="testin2", ref="master") ->
    client = Github.Client(githubToken)
    repo = client.Repo(user, repo)

    repo.getLatestCommitAt ref, (commit) ->

      files = tree.toArray().select (node) ->
        node.isFile()
      .map (file) ->
        {path, contents} = file.attributes

        path: path
        mode: "100644"
        type: "blob"
        content: contents

      data =
        tree: files

      repo.createTree data, (tree) ->
        repo.createCommit
          message: "Test Commit"
          tree: tree.sha
          parents: [commit.sha]
        , (commit) ->
          repo.updateReference(ref, commit.sha)
