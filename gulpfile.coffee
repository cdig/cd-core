beepbeep = require "beepbeep"
browser_sync = require("browser-sync").create()
chalk = require "chalk"
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
gulp_sass = require "gulp-sass"
gulp_sourcemaps = require "gulp-sourcemaps"
gulp_svgmin = require "gulp-svgmin"
gulp_uglify = require "gulp-uglify"
gulp_util = require "gulp-util"
# gulp_using = require "gulp-using" # Uncomment and npm install for debug
merge_stream = require "merge-stream"
path = require "path"


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
  watch: ["dev/*/{dist,pack}/**", "dev/cd-core/*.coffee"] # We can't say cd-core/gulpfile.coffee or it fails when we aren't doing cd-core dev

module_paths =
  basicAssets: [
    "node_modules/cd-module/pack/**/*.{#{basicAssetTypes}}"
    "source/**/*.{#{basicAssetTypes}}"
  ]
  coffee: [
    "node_modules/cd-module/pack/**/*.coffee"
    "source/**/*.coffee"
  ]
  kit:
    libs: [
      "node_modules/take-and-make/dist/take-and-make.js"
      "node_modules/normalize.css/normalize.css"
      "node_modules/cd-reset/dist/cd-reset.css"
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
  coffee: "source/**/*.coffee"
  libs: [
    "node_modules/take-and-make/dist/take-and-make.js"
    "node_modules/svga/dist/lato-bold.woff"
    "node_modules/svga/dist/lato-bold.woff2"
    "node_modules/svga/dist/lato-regular.woff"
    "node_modules/svga/dist/lato-regular.woff2"
    "node_modules/svga/dist/svga.css"
    "node_modules/svga/dist/svga.js"
  ]
  svg: "source/**/*.svg"
  wrapper: "node_modules/svga/dist/index.html"

svg_plugins = [
  {cleanupAttrs: true}
  {removeDoctype: true}
  {removeXMLProcInst: true}
  {removeComments: true}
  {removeMetadata: true}
  {removeTitle: true} # disabled by default
  {removeDesc: true}
  {removeUselessDefs: true}
  # {removeXMLNS: true} # for inline SVG, disabled by default
  {removeEditorsNSData: true}
  {removeEmptyAttrs: true}
  {removeHiddenElems: true}
  # {removeEmptyText: true}
  {removeEmptyContainers: true}
  # {removeViewBox: true} # disabled by default
  {cleanUpEnableBackground: true}
  # {minifyStyles: true}
  # {convertStyleToAttrs: true}
  {convertColors: names2hex: true, rgb2hex: true}
  {convertPathData:
    applyTransforms: true
    applyTransformsStroked: true
    makeArcs: {
      threshold: 20 # coefficient of rounding error
      tolerance: 10  # percentage of radius
    }
    straightCurves: true
    lineShorthands: true
    curveSmoothShorthands: true
    floatPrecision: 2
    transformPrecision: 2
    removeUseless: true
    collapseRepeated: true
    utilizeAbsolute: true
    leadingZero: false
    negativeExtraSpace: true
  }
  {convertTransform:
    convertToShorts: true
    degPrecision: 2 # transformPrecision (or matrix precision) - 2 by default
    floatPrecision: 2
    transformPrecision: 2
    matrixToTransform: false # Might want to try setting to true
    shortTranslate: true
    shortScale: true
    shortRotate: true
    removeUseless: true
    collapseIntoOne: true
    leadingZero: false
    negativeExtraSpace: false
  }
  {cleanupNumericValues: floatPrecision: 2}
  {sortAttrs: true}
  # {transformsWithOnePath: true} # disabled by default
  # {removeDimensions: true} # disabled by default
  # {removeAttrs: attrs: []} # disabled by default
  # {removeElementsByAttr: id: [], class: []} # disabled by default
  # {addClassesToSVGElement: classNames: []} # disabled by default
  # {addAttributesToSVGElement: attributes: []} # disabled by default
  # {removeStyleElement: true} # disabled by default
]

cd_module_svg_plugins = svg_plugins.concat [
  {removeUnknownsAndDefaults: true}
  {removeNonInheritableGroupAttrs: true}
  {removeUselessStrokeAndFill: true}
  {removeUnusedNS: true}
  {cleanupIDs: true}
  {cleanupListOfValues: floatPrecision: 2}
  {moveElemsAttrsToGroup: true}
  {moveGroupAttrsToElems: true}
  {collapseGroups: true}
  {removeRasterImages: true} # disabled by default
  {mergePaths: true}
  {convertShapeToPath: true}
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
  if predicate then cb else gulp_util.noop()

changed = (path = "public")->
  cond watchingPublic, gulp_changed path, hasChanged: gulp_changed.compareSha1Digest

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

notify = (msg)->
  cond watchingPublic, gulp_notify
    title: "👍"
    message: msg

fixFlashWeirdness = (src)->
  src
    .on "error", logAndKillError "SVG"
    .pipe gulp_replace "Lato_Regular_Regular", "Lato, sans-serif"
    .pipe gulp_replace "Lato_Bold_Bold", "Lato, sans-serif"
    .pipe gulp_replace "MEMBER_", "M_"
    .pipe gulp_replace "Layer", "L"
    .pipe gulp_replace "STROKES", "S"
    .pipe gulp_replace "FILL", "F"
    .pipe gulp_replace "writing-mode=\"lr\"", ""
    .pipe gulp_replace "baseline-shift=\"0%\"", ""
    .pipe gulp_replace "kerning=\"0\"", ""
    .pipe gulp_replace "xml:space=\"preserve\"", ""
    .pipe gulp_replace "fill-opacity=\".99\"", "" # This is close enough to 1 that it's not worth the cost


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
    .pipe gulp_sass
      precision: 2
    .pipe emitMaps()
    .pipe gulp.dest "public"
    .pipe stream "**/*.css"
    .pipe notify "SCSS"


# Clean and minify static SVG files in source and asset packs
gulp.task "cd-module:svg", ()->
  gulp.src module_paths.svg, ignore: "source/icon.svg"
    .on "error", logAndKillError "SVG"
    .pipe gulp_replace "Lato_Regular_Regular", "Lato, sans-serif"
    .pipe gulp_replace "Lato_Bold_Bold", "Lato, sans-serif"
    .pipe gulp_replace "MEMBER_", "M_"
    .pipe gulp_replace "Layer", "L"
    .pipe gulp_replace "STROKES", "S"
    .pipe gulp_replace "FILL", "F"
    .pipe gulp_replace "writing-mode=\"lr\"", ""
    .pipe gulp_replace "baseline-shift=\"0%\"", ""
    .pipe gulp_replace "kerning=\"0\"", ""
    .pipe gulp_replace "xml:space=\"preserve\"", ""
    .pipe gulp_replace "fill-opacity=\".99\"", "" # This is close enough to 1 that it's not worth the perf cost
    # svgmin stabilizes after 2 runs
    .pipe gulp_svgmin full: true, plugins: cd_module_svg_plugins
    .pipe gulp_svgmin full: true, plugins: cd_module_svg_plugins
    .pipe gulp.dest "public"


# TASKS: SVGA COMPILATION #########################################################################


# This task MUST be idempotent, since it overwrites the original file
svga_beautify_svg = (cwd, svgName, dest)-> ()->
  fixFlashWeirdness gulp.src "#{cwd}/#{svga_paths.svg}", ignore: "source/icon.svg"
    .on "error", logAndKillError "BEAUTIFY SVG"
    .pipe changed cwd + "/source"
    .pipe gulp_replace /<svg .*?(width=.+? height=.+?").*?>/, '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" xmlns:xlink="http://www.w3.org/1999/xlink" font-family="Lato, sans-serif" $1>'
    # svgmin stabilizes after 2 runs
    .pipe gulp_svgmin full: true, js2svg: { pretty: true, indent: "  " }, plugins: svg_plugins
    .pipe gulp_svgmin full: true, js2svg: { pretty: true, indent: "  " }, plugins: svg_plugins
    .pipe gulp.dest cwd + "/source"


svga_coffee_source = (cwd, svgName, dest)-> ()->
  gulp.src cwd + "/" + svga_paths.coffee
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


svga_wrap_svg = (cwd, svgName, dest)-> ()->
  libs = gulp.src svga_paths.libs
    .on "error", logAndKillError "SVG LIBS"
    .pipe gulp.dest "#{dest}/_libs"
  svgSource = gulp.src "#{cwd}/#{svga_paths.svg}", ignore: "source/icon.svg"
    .on "error", logAndKillError "SVG SOURCE"
    .pipe gulp_replace "</defs>", "</defs>\n<g id=\"root\">"
    .pipe gulp_replace "</svg>", "</g>\n</svg>"
  gulp.src svga_paths.wrapper
    .on "error", logAndKillError "SVG"
    .pipe gulp_inject svgSource, name: "source", transform: fileContents
    .pipe gulp_inject libs, name: "libs", ignorePath: dest, addRootSlash: false
    .pipe gulp_replace "<script src", "<script defer src"
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
    merge_stream svgas.map (folder)-> svga_coffee_source(folder, path.basename(folder), "public/svga/")()
  else
    cb()

gulp.task "cd-module:svga:wrap", (cb)->
  if (svgas = glob.sync(module_paths.svga.projects)).length > 0
    merge_stream svgas.map (folder)-> svga_wrap_svg(folder, path.basename(folder), "public/svga/")()
  else
    cb()


gulp.task "cd-module:svga:build",
  gulp.series "cd-module:svga:beautify", "cd-module:svga:coffee", "cd-module:svga:wrap"


gulp.task "svga:beautify", svga_beautify_svg ".", "index", "public"
gulp.task "svga:coffee", svga_coffee_source ".", "index", "public"
gulp.task "svga:wrap", svga_wrap_svg ".", "index", "public"

gulp.task "svga:build",
  gulp.series "svga:beautify", "svga:coffee", "svga:wrap"


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
    .pipe gulp_uglify()
    .pipe gulp.dest "deploy/temp"


gulp.task "deploy:optim:css", ()->
  gulp.src "public/**/*.css"
    .on "error", logAndKillError "REV OPTIM CSS"
    .pipe gulp_autoprefixer
      browsers: "Android >= 4.4, Chrome >= 44, ChromeAndroid >= 44, Edge >= 12, ExplorerMobile >= 11, IE >= 11, Firefox >= 40, iOS >= 9, Safari >= 9"
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
        rev.replace(/.*\//, "https://cdn.lunchboxsessions.com/#{era}/")
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
  gulp.watch module_paths.basicAssets, gulp.series "cd-module:basic-assets"
  gulp.watch module_paths.coffee, gulp.series "cd-module:coffee"
  gulp.watch dev_paths.watch, gulp.series "copy-dev"
  gulp.watch module_paths.kit.watch, gulp.series "cd-module:kit:compile", "reload"
  gulp.watch module_paths.scss, gulp.series "cd-module:scss"
  gulp.watch module_paths.svg, gulp.series "cd-module:svg", "reload"
  gulp.watch module_paths.svga.watch, gulp.series "cd-module:svga:build", "reload"
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
  gulp.watch dev_paths.watch, gulp.series "copy-dev"
  gulp.watch svga_paths.coffee, gulp.series "svga:coffee", "reload"
  gulp.watch svga_paths.libs, gulp.series "svga:wrap", "reload"
  gulp.watch svga_paths.wrapper, gulp.series "svga:wrap", "reload"
  gulp.watch svga_paths.svg, gulp.series "svga:beautify", "svga:wrap", "reload"
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
