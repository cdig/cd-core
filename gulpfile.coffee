{ sass } = require "@mr-hope/gulp-sass"
beepbeep = require "beepbeep"
browser_sync = require("browser-sync").create()
chalk = require "chalk"
chokidar = require "chokidar"
child_process = require "child_process"
fs = require "fs"
glob = require "glob"
gulp = require "gulp"
gulp_autoprefixer = require "gulp-autoprefixer"
gulp_clean_css = require "gulp-clean-css"
gulp_changed = require "gulp-changed"
gulp_coffee = require "gulp-coffee"
gulp_concat = require "gulp-concat"
gulp_htmlmin = require "gulp-htmlmin"
gulp_inject = require "gulp-inject"
gulp_kit = require "gulp-kit"
gulp_natural_sort = require "gulp-natural-sort"
gulp_notify = require "gulp-notify"
gulp_rename = require "gulp-rename"
gulp_replace = require "gulp-replace"
gulp_rev_all = require "gulp-rev-all"
gulp_sourcemaps = require "gulp-sourcemaps"
gulp_svgmin = require "gulp-svgmin"
gulp_terser = require "gulp-terser"
# gulp_using = require "gulp-using" # Uncomment and npm install for debug
merge_stream = require "merge-stream"
path = require "path"
SVGI = require "svgi"
through2 = require "through2"


# STATE ###########################################################################################


prod = false
watchingDeploy = false
watchingPublic = false
indexName = null


# CONFIG ##########################################################################################


era = "v4-1"

# Assets that should just be copied straight from source to public with no processing
basicAssetTypes = "css,gif,jpeg,jpg,json,m4v,min.html,mp3,mp4,pdf,png,swf,woff,woff2"

dev_paths =
  gulp: ["dev/*/gulpfile.coffee", "!dev/cd-core/**"]
  watch: ["dev/*/{dist,lib,pack}/**", "dev/cd-core/*.coffee"] # We can't say cd-core/gulpfile.coffee or it fails when we aren't doing cd-core dev

module_paths =
  basicAssets: [
    "node_modules/cd-module/pack/**/*.{#{basicAssetTypes}}"
    "source/**/*.{#{basicAssetTypes}}"
  ]
  coffee: [
    "node_modules/doom/doom.coffee"
    "node_modules/cd-module/pack/**/*.coffee"
    "source/**/*.coffee"
  ]
  kit:
    libs: [
      "node_modules/take-and-make/dist/take-and-make.js"
      "node_modules/normalize.css/normalize.css"
      "node_modules/cd-reset/dist/cd-reset.css"
      "node_modules/fonts/dist/fonts.css"
    ]
    index: "source/index.kit"
    packHtml: "node_modules/cd-module/pack/**/*.html"
    watch: [
      "source/**/*.{kit,html}"
      "node_modules/cd-module/pack/**/*.{kit,html}"
    ]
  scss: [
    "node_modules/cd-module/pack/**/*.scss"
    "source/**/*.scss"
  ]
  svg: [
    "node_modules/cd-module/pack/**/*.svg"
    "source/**/*.svg"
  ]
  svga:
    projects: "svga/*"
    watch: [
      "svga/**"
      "node_modules/svga/dist/**"
    ]

svga_paths =
  coffee:
    libs: "node_modules/doom/doom.coffee"
    source: "source/**/*.coffee"
  libs: [
    "node_modules/take-and-make/dist/take-and-make.js"
    "node_modules/fonts/dist/fonts.css"
    "node_modules/svga/dist/svga.css"
    "node_modules/svga/dist/svga.js"
  ]
  scss:
    libs: "node_modules/svga/lib/_vars.scss"
    source: "source/**/*.scss"
  svg: "source/**/*.svg"
  wrapper: "node_modules/svga/dist/index.html"

svg_plugins = [
  "cleanupEnableBackground"
  "cleanupAttrs"
  {name:"cleanupListOfValues", params: floatPrecision: 1}
  {name:"cleanupNumericValues", params: floatPrecision: 2}
  {name:"convertColors", params: names2hex: true, rgb2hex: true}
  {name:"convertPathData", params: transformPrecision: 4, floatPrecision: 1}
  "convertShapeToPath"
  "convertStyleToAttrs"
  {name: "convertTransform", params:
    transformPrecision: 4 # for scale and four first matrix parameters (needs a better precision due to multiplying)
    floatPrecision: 1 # for translate including two last matrix and rotate parameters
    degPrecision: 1 # for rotate and skew. By default it's equal to (rougly) transformPrecision - 2 or floatPrecision whichever is lower. Can be set in params.
    matrixToTransform: false
  }
  "mergePaths"
  "minifyStyles"
  "removeComments"
  "removeDesc"
  "removeDoctype"
  "removeEditorsNSData"
  "removeEmptyAttrs"
  "removeEmptyContainers"
  "removeHiddenElems"
  "removeMetadata"
  "removeNonInheritableGroupAttrs"
  # "removeRasterImages" # we need raster images for things like 3d mimics
  "removeScriptElement"
  "removeTitle"
  "removeUnusedNS"
  "removeXMLProcInst"
  "sortAttrs"

  # disabled by default
  # {name: "addAttributesToSVGElement", params: attributes: []}
  # {name: "addClassesToSVGElement", params: classNames: []}
  # {name: "removeAttrs", params: attrs: []}
  # "removeDimensions"
  # {name: "removeElementsByAttr", params: id: [], class: []}
  # "removeStyleElement"
  # "removeViewBox"
  # "removeXMLNS" # for inline SVG
]

cd_module_svg_plugins = svg_plugins.concat [
  "cleanupIDs"
  "collapseGroups"
  "moveElemsAttrsToGroup"
  "moveGroupAttrsToElems"
  "removeEmptyText"
  "removeUnknownsAndDefaults"
  "removeUselessDefs"
  "removeUselessStrokeAndFill"
]

gulp_notify.logLevel(0)
gulp_notify.on "click", ()->
  child_process.exec "open -a Terminal"


# HELPER FUNCTIONS ################################################################################


fileContents = (filePath, file)->
  file.contents.toString "utf8"

logAndKillError = (type, full = true)-> (err)->
  pwd = process.cwd() + "/"
  beepbeep()
  console.log chalk.red("\n ERROR IN YOUR #{type} 😱")
  console.log (if full then err.toString() else err.message).replace pwd, ""
  gulp_notify.onError(
    emitError: true
    icon: false
    message: err.message
    title: "😱 #{type} ERROR"
    wait: true
    )(err)
  @emit "end"

cond = (predicate, cb)->
  if predicate then cb else through2.obj()

changed = (path = "public")->
  cond watchingPublic, gulp_changed path, hasChanged: gulp_changed.compareContents

delSync = (path)->
  if fs.existsSync path
    for file in fs.readdirSync path
      curPath = path + "/" + file
      if fs.lstatSync(curPath).isDirectory()
        delSync curPath
      else
        fs.unlinkSync curPath
      null
    fs.rmdirSync path

openDeploy = ()->
  child_process.exec "open deploy/all/#{indexName}"

stream = (glob)->
  cond watchingPublic, browser_sync.stream match: glob

stripPack = (path)->
  path.dirname = path.dirname.replace /.*\/pack\//, ''
  path

initMaps = ()->
  cond !prod, gulp_sourcemaps.init()

emitMaps = ()->
  cond !prod, gulp_sourcemaps.write "."

devWrapPageStart = ()->
  cond !prod, gulp_replace "<body>", """
    <body style="padding-top: 48px;">
      <div id="header" style="display: flex; align-items: center; justify-content: center; position: fixed; top: 0; left: 0; width: 100vw; height: 48px; background: linear-gradient(to right, #35488d, #446dc1, #35488d); box-shadow: 0 2px 6px rgba(53,72,141,0.5); border-bottom: 1px solid rgba(53,72,141,0.6); z-index: 2001;">
        <svg style="margin-top: 1px" xmlns="http://www.w3.org/2000/svg" width="44" height="33" fill="#FFF" fill-opacity=".95" viewBox="0 0 200 150">
      <path d="M51 112q5.3 3 10 5l3.7-7q-8.7-3-15.1-7-4.6-2.6-9.1-6L10 107.7q-1.6-1.7-2.4-2.4Q6 104 5 102.4q-3-4-5-10.4 1 9 4 15 3 5 8 9.3l29-10.6q4 3.3 10 6.3M29 67L2.5 64.7 4 72l24 2v-3.3q.3-1.3 1-3.7m140.3 35.7l28.1 8.9 2.6-7.6-30.3-9q-5.7 7-16.7 12.5l5 5q4.4-2.8 7-5.2 2-1.9 4.3-4.6m5.1 26.9q-6.4 3.7-12.4 6-7 2.8-15.4 4.4L127 115.3q-9 1.2-15 1.4-7 .3-16.4-.4L85.3 142q-10.9-1-20.7-3.5-7.6-2-13.6-4.5l.3 8q8.3 3.5 16.7 5.3 6.7 1.7 17 2.7l10-25.6q18 1.3 31.5-.9L145 148q7.5-1.6 14-4 7.7-2.7 13-6l2.4-8.4M173 73l17-2 2-6.3-21 2.3q1 1.6 1.3 3 .7 1 .7 3zm-7-24l2-20-7-18h-15l-5-11H67l-5 11H47l-7 18 2 20h5l4 45h106l4-45h5M136 5l3 6H69l3-6h64M67 42h11l1 18H68l-1-18m63 0h11l-1 18h-11l1-18z"></path>
        </svg>
      </div>
      <div id="page">
    """

devWrapPageEnd = ()->
  cond !prod, gulp_replace "</body>", '</div></body>'

notify = (msg)->
  cond watchingPublic, gulp_notify
    title: "👍"
    message: msg

fixFlashWeirdness = (src)->
  src
    .on "error", logAndKillError "SVG"
    .pipe gulp_replace "Architects_Daughter_Regular", "ArchitectsDaughter, sans-serif"
    .pipe gulp_replace "Comic_Sans_MS_Regular", "Comic Sans MS, sans-serif"
    .pipe gulp_replace "Comic_Sans_MS_Bold_Bold", "Comic Sans MS, sans-serif"
    .pipe gulp_replace "Helsinki_Regular", "Helsinki, sans-serif"
    .pipe gulp_replace "Lato_Hairline_Regular", "Lato, sans-serif\" font-weight=\"200"
    .pipe gulp_replace "Lato_Hairline_Italic", "Lato, sans-serif\" font-weight=\"200"
    .pipe gulp_replace "Lato_Thin_Regular", "Lato, sans-serif\" font-weight=\"200"
    .pipe gulp_replace "Lato_Thin_Italic", "Lato, sans-serif\" font-weight=\"200"
    .pipe gulp_replace "Lato_Light_Regular", "Lato, sans-serif\" font-weight=\"300"
    .pipe gulp_replace "Lato_Light_Italic", "Lato, sans-serif\" font-weight=\"300"
    .pipe gulp_replace "Lato_Regular_Regular", "Lato, sans-serif"
    .pipe gulp_replace "Lato_Regular_Italic", "Lato, sans-serif"
    .pipe gulp_replace "Lato_Medium_Regular", "Lato, sans-serif\" font-weight=\"500"
    .pipe gulp_replace "Lato_Medium_Italic", "Lato, sans-serif\" font-weight=\"500"
    .pipe gulp_replace "Lato_Semibold_Regular", "Lato, sans-serif\" font-weight=\"600"
    .pipe gulp_replace "Lato_Semibold_Italic", "Lato, sans-serif\" font-weight=\"600"
    .pipe gulp_replace "Lato_Bold_Bold", "Lato, sans-serif"
    .pipe gulp_replace "Lato_Bold_BoldItalic", "Lato, sans-serif" # Not sure if this works
    .pipe gulp_replace "Lato_Heavy_Regular", "Lato, sans-serif\" font-weight=\"700"
    .pipe gulp_replace "Lato_Heavy_Italic", "Lato, sans-serif\" font-weight=\"700"
    .pipe gulp_replace "Lato_Black_Regular", "Lato, sans-serif\" font-weight=\"900"
    .pipe gulp_replace "Lato_Black_Italic", "Lato, sans-serif\" font-weight=\"900"
    .pipe gulp_replace "Rock_Salt_Regular", "RockSalt, sans-serif"
    .pipe gulp_replace /<text clip-path=".*?"/g, '<text'
    .pipe gulp_replace "MEMBER_", "M_"
    .pipe gulp_replace "Layer", "L"
    .pipe gulp_replace "STROKES", "S"
    .pipe gulp_replace "FILL", "F"
    .pipe gulp_replace "writing-mode=\"lr\"", ""
    .pipe gulp_replace "baseline-shift=\"0%\"", ""
    .pipe gulp_replace "kerning=\"0\"", ""
    .pipe gulp_replace "xml:space=\"preserve\"", ""
    .pipe gulp_replace "fill-opacity=\".99\"", "" # This is close enough to 1 that it's not worth the cost


# WATCHING ########################################################################################


queue = []
tasksRunning = false

runTasks = ()->
  if queue.length > 0
    tasksRunning = true
    task = queue.shift()
    await new Promise (resolve)-> task resolve
    runTasks()
  else
    tasksRunning = false

watch = (paths, task)->
  chokidar.watch(paths, ignoreInitial:true).on "all", ()->
    if task not in queue
      queue.push task
      runTasks() unless tasksRunning


# TASKS: MODULE COMPILATION #######################################################################


# Copy all basic assets in source and asset packs to public
gulp.task "cd-module:basic-assets", ()->
  gulp.src module_paths.basicAssets
    .on "error", logAndKillError "BASIC ASSETS"
    .pipe gulp_rename stripPack
    .pipe changed()
    .pipe gulp.dest "public"
    .pipe stream "**/*.{#{basicAssetTypes},html}"


# Compile coffee in source and asset packs, with sourcemaps in dev and uglify in prod
gulp.task "cd-module:coffee", ()->
  gulp.src module_paths.coffee
    .on "error", logAndKillError "COFFEE"
    .pipe gulp_natural_sort()
    .pipe initMaps()
    .pipe gulp_concat "scripts.coffee"
    .pipe gulp_coffee()
    .pipe emitMaps()
    .pipe gulp.dest "public"
    .pipe stream "**/*.js"
    .pipe notify "Coffee"


gulp.task "cd-module:kit:compile", ()->
  libs = gulp.src module_paths.kit.libs
    .on "error", logAndKillError "KIT LIBS"
    .pipe gulp.dest "public/_libs"
  packHtml = gulp.src module_paths.kit.packHtml
    .on "error", logAndKillError "KIT PACK HTML"
    .pipe gulp_natural_sort()
  gulp.src module_paths.kit.index
    .on "error", logAndKillError "KIT"
    .pipe gulp_kit()
    .pipe gulp_inject libs, name: "libs", ignorePath: "/public/", addRootSlash: false
    .pipe gulp_inject packHtml, name: "pack", transform: fileContents
    .pipe gulp_replace "<script src=\"_libs", "<script defer src=\"_libs"
    .pipe devWrapPageStart()
    .pipe devWrapPageEnd()
    .pipe gulp_htmlmin # Do this in both dev and prod, so folks can see if it causes weirdness
      collapseWhitespace: true
      collapseBooleanAttributes: true
      collapseInlineTagWhitespace: false
      includeAutoGeneratedTags: false
      removeComments: true
    .pipe gulp.dest "public"
    .pipe notify "HTML"


gulp.task "cd-module:kit:fix", ()->
  gulp.src module_paths.kit.index
    .on "error", logAndKillError "KIT FIX"
    .pipe gulp_replace "bower_components", "node_modules"
    .pipe gulp.dest "source"


# Compile scss in source and asset packs, with sourcemaps in dev and autoprefixer in prod
gulp.task "cd-module:scss", ()->
  gulp.src module_paths.scss
    .on "error", logAndKillError "SCSS", false
    .pipe gulp_natural_sort()
    .pipe initMaps()
    .pipe gulp_concat "styles.scss"
    .pipe sass(precision: 2).on "error", logAndKillError "SCSS", false
    .pipe emitMaps()
    .pipe gulp.dest "public"
    .pipe stream "**/*.css"
    .pipe notify "SCSS"


# Clean and minify static SVG files in source and asset packs
gulp.task "cd-module:svg", ()->
  fixFlashWeirdness gulp.src module_paths.svg, ignore: "source/icon.svg"
    # svgmin stabilizes after 2 runs
    .pipe gulp_svgmin full: true, plugins: cd_module_svg_plugins
    .pipe gulp_svgmin full: true, plugins: cd_module_svg_plugins
    # Keep this in sync with https://github.com/cdig/fonts
    .pipe gulp_replace "<svg", '<svg text-rendering="geometricPrecision"'
    .pipe gulp_replace '</svg>', """
        <style>
          @font-face { font-family: "Architect's Daughter"; font-weight: normal; font-style: normal; src: url("https://d3gc444e269pac.cloudfront.net/fonts/architects-daughter/architects-daughter.woff2") format("woff2"); }
          @font-face { font-family: "ArchitectsDaughter"; font-weight: normal; font-style: normal; src: url("https://d3gc444e269pac.cloudfront.net/fonts/architects-daughter/architects-daughter.woff2") format("woff2"); }
          @font-face { font-family: "Helsinki"; font-weight: normal; font-style: normal; src: url("https://d3gc444e269pac.cloudfront.net/fonts/helsinki/helsinki.woff"); }
          @font-face { font-family: "Lato"; font-weight: bold; font-style: normal; src: url("https://d3gc444e269pac.cloudfront.net/fonts/lato/lato-bold.woff2") format("woff2"); }
          @font-face { font-family: "Lato"; font-weight: normal; font-style: italic; src: url("https://d3gc444e269pac.cloudfront.net/fonts/lato/lato-italic.woff2") format("woff2"); }
          @font-face { font-family: "Lato"; font-weight: normal; font-style: normal; src: url("https://d3gc444e269pac.cloudfront.net/fonts/lato/lato-regular.woff2") format("woff2"); }
          @font-face { font-family: "Rock Salt"; font-weight: normal; font-style: normal; src: url("https://d3gc444e269pac.cloudfront.net/fonts/rock-salt/rock-salt.woff") format("woff"); }
          @font-face { font-family: "RockSalt"; font-weight: normal; font-style: normal; src: url("https://d3gc444e269pac.cloudfront.net/fonts/rock-salt/rock-salt.woff") format("woff"); }
        </style>
      </svg>"""
    .pipe gulp.dest "public"


# TASKS: SVGA COMPILATION #########################################################################


# This task MUST be idempotent, since it overwrites the original file
svga_beautify_svg = (cwd, svgName, dest)-> ()->
  fixFlashWeirdness gulp.src "#{cwd}/#{svga_paths.svg}", ignore: "source/icon.svg"
    .on "error", logAndKillError "BEAUTIFY SVG"
    .pipe changed cwd + "/source"
    .pipe gulp_replace /<svg .*?(width=.+? height=.+?").*?>/, '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" xmlns:xlink="http://www.w3.org/1999/xlink" font-family="Lato, sans-serif" text-rendering="geometricPrecision" $1>'
    # svgmin stabilizes after 2 runs
    .pipe gulp_svgmin full: true, js2svg: { pretty: true, indent: "  " }, plugins: svg_plugins
    .pipe gulp_svgmin full: true, js2svg: { pretty: true, indent: "  " }, plugins: svg_plugins
    .pipe gulp.dest cwd + "/source"


svga_coffee_source = (cwd, svgName, dest)-> ()->
  sourceFullPath = cwd + "/" + svga_paths.coffee.source
  gulp.src [].concat sourceFullPath, svga_paths.coffee.libs
    .on "error", logAndKillError "COFFEE"
    .pipe gulp_natural_sort()
    .pipe initMaps()
    .pipe gulp_concat "source.coffee"
    .pipe gulp_coffee()
    .pipe gulp_rename (path)->
      path.basename = svgName
      path
    .pipe emitMaps()
    .pipe gulp.dest dest
    .pipe stream "**/*.js"
    .pipe notify "Coffee"


svga_scss_source = (cwd, svgName, dest)-> ()->
  gulp.src [].concat svga_paths.scss.libs, "#{cwd}/#{svga_paths.scss.source}"
    .on "error", logAndKillError "SCSS", false
    .pipe gulp_natural_sort()
    .pipe initMaps()
    .pipe gulp_concat "styles.scss"
    .pipe sass(precision: 2).on "error", logAndKillError "SCSS", false
    .pipe gulp_rename (path)->
      path.basename = svgName
      path
    .pipe emitMaps()
    .pipe gulp.dest dest
    .pipe stream "**/*.css"
    .pipe notify "SCSS"


svga_wrap_svg = (cwd, svgName, dest)-> ()->
  # We wrap this up in our current scope so that multiple SVGs being processed in parallel don't fight over the rootMade global
  rootMade = false
  makeRoot = (v)->
    return v if rootMade
    rootMade = true
    v + "\n<g id=\"root\">"

  libs = gulp.src svga_paths.libs
    .on "error", logAndKillError "SVG LIBS"
    .pipe gulp.dest "#{dest}/_libs"
  svgSource = gulp.src "#{cwd}/#{svga_paths.svg}", ignore: "source/icon.svg"
    .on "error", logAndKillError "SVG SOURCE"
    .pipe gulp_replace "</defs>", makeRoot
    .pipe gulp_replace /<svg.*?>/, makeRoot
    .pipe gulp_replace "</svg>", "</g>\n</svg>"
    .pipe gulp_replace "<svg ", "<svg id=\"svga\" "
    .pipe gulp_replace "<svg", (tag)->
      svgi = new SVGI this.file.contents.toString()
      nodeCount = svgi.report().stats.totalNodes
      tag + " node-count=\"#{nodeCount}\""
  gulp.src svga_paths.wrapper
    .on "error", logAndKillError "SVG"
    .pipe gulp_inject svgSource, name: "source", transform: fileContents
    .pipe gulp_inject libs, name: "libs", ignorePath: dest, addRootSlash: false
    .pipe gulp_replace "<script src", "<script defer src"
    .pipe gulp_replace "href=\"svga-css/source.css", "href=\"svga-css/#{svgName}.css"
    .pipe gulp_replace "src=\"svga-js/source.js", "src=\"svga-js/#{svgName}.js"
    .pipe cond prod, gulp_htmlmin
      collapseWhitespace: true
      collapseBooleanAttributes: true
      collapseInlineTagWhitespace: true
      includeAutoGeneratedTags: false
      removeComments: true
    .pipe gulp_rename (path)->
      path.basename = svgName
      path
    .pipe gulp.dest dest
    .pipe notify "SVG"


gulp.task "cd-module:svga-check", (cb)->
  if fs.existsSync("source/svga")
    throw "\n\n\n  You have a folder named 'svga' inside your source folder. It should be beside your source folder.\n\n"
  cb()

gulp.task "cd-module:svga:beautify", (cb)->
  if (svgas = glob.sync(module_paths.svga.projects)).length > 0
    merge_stream svgas.map (folder)-> svga_beautify_svg(folder, path.basename(folder), "public/svga/")()
  else
    cb()

gulp.task "cd-module:svga:coffee", (cb)->
  if (svgas = glob.sync(module_paths.svga.projects)).length > 0
    merge_stream svgas.map (folder)-> svga_coffee_source(folder, path.basename(folder), "public/svga/svga-js")()
  else
    cb()

gulp.task "cd-module:svga:scss", (cb)->
  if (svgas = glob.sync(module_paths.svga.projects)).length > 0
    merge_stream svgas.map (folder)-> svga_scss_source(folder, path.basename(folder), "public/svga/svga-css")()
  else
    cb()

gulp.task "cd-module:svga:wrap", (cb)->
  if (svgas = glob.sync(module_paths.svga.projects)).length > 0
    merge_stream svgas.map (folder)-> svga_wrap_svg(folder, path.basename(folder), "public/svga/")()
  else
    cb()


gulp.task "cd-module:svga:build",
  gulp.series "cd-module:svga:beautify", "cd-module:svga:coffee", "cd-module:svga:scss", "cd-module:svga:wrap"


gulp.task "svga:beautify", svga_beautify_svg ".", "index", "public"
gulp.task "svga:coffee", svga_coffee_source ".", "index", "public/svga-js"
gulp.task "svga:scss", svga_scss_source ".", "index", "public/svga-css"
gulp.task "svga:wrap", svga_wrap_svg ".", "index", "public"

gulp.task "svga:build",
  gulp.series "svga:beautify", "svga:coffee", "svga:scss", "svga:wrap"


# TASKS: DEPLOY ###################################################################################


gulp.task "deploy:del", (cb)->
  delSync "deploy"
  cb()


gulp.task "deploy:copy", ()->
  gulp.src ["public/**", "!**.{js,css}"]
    .on "error", logAndKillError "REV COPY"
    .pipe gulp.dest "deploy/temp"


gulp.task "deploy:optim:js", ()->
  gulp.src "public/**/*.js"
    .on "error", logAndKillError "REV OPTIM JS"
    .pipe gulp_replace /^(.)/, '"use strict";$1' # We'd prefer to do this in dev, but that messes with source maps
    .pipe gulp_terser()
    .pipe gulp.dest "deploy/temp"


gulp.task "deploy:optim:css", ()->
  gulp.src "public/**/*.css"
    .on "error", logAndKillError "REV OPTIM CSS"
    .pipe gulp_autoprefixer
      overrideBrowserslist: "Chrome >= 42, ChromeAndroid >= 64, Edge >= 14, Firefox >= 48, FirefoxAndroid >= 57, IE >= 11, iOS >= 10, Opera >= 48, Safari >= 10, UCAndroid >= 11"
      cascade: false
      remove: false
    .pipe gulp_clean_css
      compatibility: "*,-properties.zeroUnits"
      inline: false # Experimental fix to font loading issues
      level: 2
      rebaseTo: "public"
    .pipe gulp.dest "deploy/temp"


gulp.task "deploy:finish", ()->
  gulp.src "deploy/temp/**"
    .on "error", logAndKillError "REV FINISH"
    .pipe gulp_rev_all.revision
      transformPath: (rev, source, path)-> # Applies to file references inside HTML/CSS/JS
        "https://cdn.lunchboxsessions.com/#{era}/" + rev.replace(/.*\//, "")
      transformFilename: (file, hash)-> # Applies to the files themselves
        name = file.revHash + file.extname
        if file.revPathOriginal.indexOf("/deploy/temp/index.html") > 0
          child_process.execSync "mkdir -p deploy/index && touch deploy/index/#{name}"
          indexName = name
        name
    .pipe gulp_rename (path)->
      path.dirname = ""
      path
    .pipe gulp.dest "deploy/all"


gulp.task "deploy:open", (cb)->
  openDeploy()
  cb()


gulp.task "deploy:create",
  gulp.series "deploy:del", "deploy:copy", "deploy:optim:js", "deploy:optim:css", "deploy:finish"


gulp.task "deploy-and-open",
  gulp.series "deploy:create", "deploy:open"


# TASKS: GENERAL ##################################################################################


gulp.task "del-public", (cb)->
  delSync "public"
  cb()


gulp.task "copy-dev", (cb)->
  gulp.src dev_paths.watch, base: "dev"
    .pipe gulp.dest "node_modules"


gulp.task "dev:gulp", (cb)->
  gulp.src dev_paths.gulp
    .on "error", logAndKillError "DEV"
    .on "data", (chunk)->
      folder = chunk.path.replace "/gulpfile.coffee", ""
      process.chdir folder
      child = child_process.spawn "gulp", ["default"]
      child.stdout.on "data", (data)->
        console.log chalk.green(folder.replace chunk.base, "") + " " + chalk.white data.toString() if data
      process.chdir "../.."
  cb()


gulp.task "reload", (cb)->
  if watchingDeploy
    do gulp.series "deploy-and-open"
  if watchingPublic
    browser_sync.reload()
  cb()


gulp.task "serve", (cb)->
  browser_sync.init
    ghostMode: false
    notify: false
    server: baseDir: "public"
    ui: false
    watchOptions: ignoreInitial: true
  cb()


# TASKS: MODULE MAIN ##############################################################################


gulp.task "cd-module:watch", (cb)->
  watch module_paths.basicAssets, gulp.series "cd-module:basic-assets"
  watch module_paths.coffee, gulp.series "cd-module:coffee"
  watch dev_paths.watch, gulp.series "copy-dev"
  watch module_paths.kit.watch, gulp.series "cd-module:kit:compile", "reload"
  watch module_paths.scss, gulp.series "cd-module:scss"
  watch module_paths.svg, gulp.series "cd-module:svg", "reload"
  watch module_paths.svga.watch, gulp.series "cd-module:svga:build", "reload"
  cb()


gulp.task "cd-module:compile",
  gulp.series "cd-module:svga-check", "del-public", "copy-dev", "cd-module:kit:fix", "cd-module:basic-assets", "cd-module:coffee", "cd-module:scss", "cd-module:svg", "cd-module:svga:build", "cd-module:kit:compile"


gulp.task "cd-module:dev", (cb)->
  watchingPublic = true
  do gulp.series "dev:gulp", "cd-module:compile", "cd-module:watch", "serve"
  cb()


gulp.task "cd-module:prod", (cb)->
  prod = true
  do gulp.series "cd-module:compile", "deploy:create"
  cb()


# TASKS: SVGA MAIN ################################################################################


gulp.task "svga:watch", (cb)->
  watch dev_paths.watch, gulp.series "copy-dev", "svga:wrap", "reload"
  watch svga_paths.coffee.source, gulp.series "svga:coffee", "reload"
  watch svga_paths.libs, gulp.series "svga:wrap", "reload"
  watch svga_paths.scss.source, gulp.series "svga:scss"
  watch svga_paths.wrapper, gulp.series "svga:wrap", "reload"
  watch svga_paths.svg, gulp.series "svga:beautify", "svga:wrap", "reload"
  cb()


gulp.task "svga:compile",
  gulp.series "del-public", "copy-dev", "svga:build"


gulp.task "svga:debug", (cb)->
  prod = true
  watchingDeploy = true
  do gulp.series "dev:gulp", "svga:compile", "svga:watch", "deploy-and-open"
  cb()


gulp.task "svga:dev", (cb)->
  watchingPublic = true
  do gulp.series "dev:gulp", "svga:compile", "svga:watch", "serve"
  cb()


gulp.task "svga:prod", (cb)->
  prod = true
  do gulp.series "svga:compile", "deploy:create"
  cb()
