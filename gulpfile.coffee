beepbeep = require "beepbeep"
browser_sync = require("browser-sync").create()
chalk = require "chalk"
del = require "del"
glob = require "glob"
gulp = require "gulp"
gulp_autoprefixer = require "gulp-autoprefixer"
gulp_changed = require "gulp-changed"
gulp_coffee = require "gulp-coffee"
gulp_concat = require "gulp-concat"
gulp_htmlmin = require "gulp-htmlmin"
gulp_if = require "gulp-if"
gulp_inject = require "gulp-inject"
gulp_kit = require "gulp-kit"
gulp_natural_sort = require "gulp-natural-sort"
gulp_notify = require "gulp-notify"
gulp_rename = require "gulp-rename"
gulp_replace = require "gulp-replace"
gulp_rev_all = require "gulp-rev-all"
gulp_sass = require "gulp-sass"
gulp_shell = require "gulp-shell"
gulp_sourcemaps = require "gulp-sourcemaps"
gulp_svgmin = require "gulp-svgmin"
gulp_uglify = require "gulp-uglify"
# gulp_using = require "gulp-using" # Uncomment and npm install for debug
lazypipe = require "lazypipe"
merge_stream = require "merge-stream"
path = require "path"
spawn = require("child_process").spawn


# STATE ###########################################################################################


prod = false
watching = false


# CONFIG ##########################################################################################


# Deps that conform to the Asset Pack pattern (ie: they contain a pack folder)
assetPacks = "{cd-module,pressure}"

# Assets that should just be copied straight from source to public with no processing
basicAssetTypes = "cdig,gif,jpeg,jpg,json,m4v,min.html,mp3,mp4,pdf,png,swf,txt,woff,woff2"

dev_paths =
  gulp: "dev/*/gulpfile.coffee"
  watch: "dev/**/{dist,pack}/**/*"

module_paths =
  basicAssets: [
    "node_modules/#{assetPacks}/pack/**/*.{#{basicAssetTypes}}"
    "source/**/*.{#{basicAssetTypes}}"
  ]
  coffee: [
    "node_modules/#{assetPacks}/pack/**/*.coffee"
    "source/**/*.coffee"
  ]
  kit:
    libs: [
      "node_modules/take-and-make/dist/take-and-make.js"
      "node_modules/normalize.css/normalize.css"
      "node_modules/cd-reset/dist/cd-reset.css"
    ]
    index: "source/index.kit"
    packHtml: "node_modules/#{assetPacks}/pack/**/*.html"
    watch: [
      "source/**/*.{kit,html}"
      "node_modules/#{assetPacks}/pack/**/*.{kit,html}"
    ]
  scss: [
    "node_modules/#{assetPacks}/pack/**/vars.scss"
    "source/**/vars.scss"
    "node_modules/#{assetPacks}/pack/**/*.scss"
    "source/**/*.scss"
  ]
  svg: [
    "node_modules/#{assetPacks}/pack/**/*.svg"
    "source/**/*.svg"
  ]

svga_paths =
  coffee: "source/**/*.coffee"
  libs: [
    "node_modules/take-and-make/dist/take-and-make.js"
    # "node_modules/pressure/dist/pressure.js"
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
  {removeEmptyText: true}
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

cd_module_svg_plugins = [
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
  do gulp_shell.task "open -a Terminal"


# HELPER FUNCTIONS ################################################################################


fileContents = (filePath, file)->
  file.contents.toString "utf8"

logAndKillError = (err)->
  beepbeep()
  console.log chalk.bgRed("\n## Error ##")
  console.log chalk.red err.toString() + "\n"
  gulp_notify.onError(
    emitError: true
    icon: false
    message: err.message
    title: "👻"
    wait: true
    )(err)
  @emit "end"

cond = (predicate, action)->
  if predicate
    action()
  else
    # This is what we use as a noop *shrug*
    gulp_rename (p)-> p

changed = (path = "public")->
  cond watching, ()->
    gulp_changed path, hasChanged: gulp_changed.compareSha1Digest

stream = (glob)->
  cond watching, ()->
    browser_sync.stream match: glob

stripPack = (path)->
  path.dirname = path.dirname.replace /.*\/pack\//, ''
  path

initMaps = ()->
  cond !prod, ()->
    gulp_sourcemaps.init()

emitMaps = ()->
  cond !prod, ()->
    gulp_sourcemaps.write "."

notify = (msg)->
  cond watching, ()->
    gulp_notify
      title: "👍"
      message: msg

fixFlashWeirdness = (src)->
  src
    .on "error", logAndKillError
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
gulp.task "module:basicAssets", ()->
  gulp.src module_paths.basicAssets
    .pipe gulp_rename stripPack
    .pipe changed()
    .pipe gulp.dest "public"
    .pipe stream "**/*.{#{basicAssetTypes},html}"


# Compile coffee in source and asset packs, with sourcemaps in dev and uglify in prod
gulp.task "module:coffee", ()->
  gulp.src module_paths.coffee
    .pipe gulp_natural_sort()
    .pipe initMaps()
    .pipe gulp_concat "scripts.coffee"
    .pipe gulp_coffee()
    .on "error", logAndKillError
    .pipe cond prod, ()-> gulp_uglify()
    .pipe emitMaps()
    .pipe gulp.dest "public"
    .pipe stream "**/*.js"
    .pipe notify "Coffee"


gulp.task "module:kit:compile", ()->
  libs = gulp.src module_paths.kit.libs
    .pipe gulp.dest "public/_libs"
  packHtml = gulp.src module_paths.kit.packHtml
    .pipe gulp_natural_sort()
  gulp.src module_paths.kit.index
    .pipe gulp_kit()
    .on "error", logAndKillError
    .pipe gulp_inject libs, name: "libs", ignorePath: "/public/", addRootSlash: false
    .pipe gulp_inject packHtml, name: "pack", transform: fileContents
    .pipe gulp_replace "<script src=\"_libs", "<script defer src=\"_libs"
    .pipe gulp.dest "public"
    .pipe notify "HTML"


gulp.task "module:kit:fix", ()->
  gulp.src module_paths.kit.index
    .pipe gulp_replace "bower_components", "node_modules"
    .pipe gulp.dest "source"


gulp.task "module:kit",
  gulp.series "module:kit:fix", "module:kit:compile"


# Compile scss in source and asset packs, with sourcemaps in dev and autoprefixer in prod
gulp.task "module:scss", ()->
  gulp.src module_paths.scss
    # .pipe gulp_natural_sort()
    .pipe initMaps()
    .pipe gulp_concat "styles.scss"
    .pipe gulp_sass
      errLogToConsole: true
      outputStyle: "compressed"
      precision: 2
    .on "error", logAndKillError
    .pipe cond prod, ()-> gulp_autoprefixer
      browsers: "Android >= 4.4, Chrome >= 44, ChromeAndroid >= 44, Edge >= 12, ExplorerMobile >= 11, IE >= 11, Firefox >= 40, iOS >= 9, Safari >= 9"
      cascade: false
      remove: false
    .pipe emitMaps()
    .pipe gulp.dest "public"
    .pipe stream "**/*.css"
    .pipe notify "SCSS"


# Clean and minify static SVG files in source and asset packs
gulp.task "module:svg", ()->
  gulp.src module_paths.svg
    .on "error", logAndKillError
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
    .pipe gulp_svgmin (file)-> {full: true, plugins: svg_plugins.concat(cd_module_svg_plugins)}
    .pipe gulp.dest "public"


# TASKS: SVGA COMPILATION #########################################################################


# This task MUST be idempotent, since it overwrites the original file
svga_beautify_svg = (cwd = ".")->
  fixFlashWeirdness gulp.src cwd + "/" + svga_paths.svg
    .pipe changed "source"
    .pipe gulp_replace /<svg .*?(width=.+? height=.+?").*?>/, '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" xmlns:xlink="http://www.w3.org/1999/xlink" font-family="Lato, sans-serif" $1>'
    .on "error", logAndKillError
    .pipe gulp_svgmin
      full: true
      js2svg:
        pretty: true
        indent: "  "
      plugins: svg_plugins
    .pipe gulp.dest cwd + "/source"


svga_coffee_source = (cwd = ".")->
  gulp.src cwd + "/" + svga_paths.coffee
    .pipe gulp_natural_sort()
    .pipe initMaps()
    .pipe gulp_concat "source.coffee"
    .pipe gulp_coffee()
    .on "error", logAndKillError
    .pipe cond prod, gulp_uglify
    .pipe emitMaps()
    .pipe gulp.dest "public/" + path.basename(cwd)
    .pipe stream "**/*.js"
    .pipe notify "Coffee"


svga_wrap_svg = (cwd = ".")->
  libs = gulp.src svga_paths.libs
    .pipe gulp.dest "public/_libs"
  svgSource = gulp.src svga_paths.svg
    .pipe gulp_replace "</defs>", "</defs>\n<g id=\"root\">"
    .pipe gulp_replace "</svg>", "</g>\n</svg>"
  gulp.src svga_paths.wrapper
    .pipe gulp_inject svgSource, name: "source", transform: fileContents
    .pipe gulp_inject libs, name: "libs", ignorePath: "/public/", addRootSlash: false
    .pipe gulp_replace "<script src=\"_libs", "<script defer src=\"_libs"
    .pipe cond prod, ()-> gulp_htmlmin
      collapseWhitespace: true
      collapseBooleanAttributes: true
      collapseInlineTagWhitespace: true
      includeAutoGeneratedTags: false
      removeComments: true
    .on "error", logAndKillError
    .pipe gulp.dest "public/" + path.basename(cwd)
    .pipe notify "SVG"


gulp.task "svga:beautify-svg", svga_beautify_svg
gulp.task "svga:coffee:source", svga_coffee_source
gulp.task "svga:wrap-svg", svga_wrap_svg


# TASKS: SYSTEM ###################################################################################


gulp.task "del:public", ()->
  del "public"


gulp.task "del:deploy", ()->
  del "deploy"


gulp.task "dev", gulp_shell.task [
  'if [ -d "dev" ]; then rsync --exclude "*/.git/" --delete -ar dev/* node_modules; fi'
]


gulp.task "dev:watch", (cb)->
  gulp.src dev_paths.gulp
    .on "data", (chunk)->
      folder = chunk.path.replace "/gulpfile.coffee", ""
      process.chdir folder
      child = spawn "gulp", ["default"]
      child.stdout.on "data", (data)->
        console.log chalk.green(folder.replace chunk.base, "") + " " + chalk.white data.toString() if data
      process.chdir "../.."
  cb()


gulp.task "prod:setup", (cb)->
  prod = true
  cb()


gulp.task "reload", (cb)->
  browser_sync.reload()
  cb()


gulp.task "rev", ()->
  gulp.src "public/**"
    .pipe gulp_rev_all.revision
      transformPath: (rev, source, path)-> # Applies to file references inside HTML/CSS/JS
        rev.replace /.*\//, ""
      transformFilename: (file, hash)->
        name = file.revHash + file.extname
        gulp_shell.task("mkdir -p deploy/index && touch deploy/index/#{name}")() if file.revPathOriginal.indexOf("/public/index.html") > 0
        name
    .pipe gulp_rename (path)->
      path.dirname = ""
      path
    .pipe gulp.dest "deploy/all"


gulp.task "serve", ()->
  browser_sync.init
    ghostMode: false
    notify: false
    server: baseDir: "public"
    ui: false
    watchOptions: ignoreInitial: true


# MODULE MAIN #####################################################################################


gulp.task "module:svga:beautify", ()->
  merge_stream glob.sync('svga/*').map (folder)->
    svga_beautify_svg folder

gulp.task "module:svga:coffee", ()->
  merge_stream glob.sync('svga/*').map (folder)->
    svga_coffee_source folder

gulp.task "module:svga:wrap", ()->
  merge_stream glob.sync('svga/*').map (folder)->
    svga_wrap_svg folder

gulp.task "module:svga",
  gulp.series "module:svga:beautify", "module:svga:coffee", "module:svga:wrap"


gulp.task "module:watch", (cb)->
  watching = true
  gulp.watch module_paths.basicAssets, gulp.series "module:basicAssets"
  gulp.watch module_paths.coffee, gulp.series "module:coffee"
  gulp.watch dev_paths.watch, gulp.series "dev"
  gulp.watch module_paths.kit.watch, gulp.series "module:kit", "reload"
  gulp.watch module_paths.scss, gulp.series "module:scss"
  gulp.watch module_paths.svg, gulp.series "module:svg", "reload"
  cb()


gulp.task "module:recompile",
  gulp.series "del:public", "dev", "module:basicAssets", "module:coffee", "module:scss", "module:svg", "module:kit"


gulp.task "module:prod",
  gulp.series "prod:setup", "module:recompile", "del:deploy", "rev"


gulp.task "module:dev",
  gulp.series "module:recompile", "module:watch", "serve"


# SVGA MAIN #######################################################################################


gulp.task "svga:watch", (cb)->
  watching = true
  gulp.watch dev_paths.watch, gulp.series "dev"
  gulp.watch svga_paths.coffee, gulp.series "svga:coffee:source"
  gulp.watch svga_paths.libs, gulp.series "svga:wrap-svg", "reload"
  gulp.watch svga_paths.wrapper, gulp.series "svga:wrap-svg", "reload"
  gulp.watch svga_paths.svg, gulp.series "svga:beautify-svg", "svga:wrap-svg", "reload"
  cb()


gulp.task "svga:recompile",
  gulp.series "del:public", "dev", "svga:beautify-svg", "svga:coffee:source", "svga:wrap-svg"


gulp.task "svga:prod",
  gulp.series "prod:setup", "svga:recompile", "del:deploy", "rev"


gulp.task "svga:dev",
  gulp.series "dev:watch", "svga:recompile", "svga:watch", "serve"
