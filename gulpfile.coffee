beepbeep = require "beepbeep"
browser_sync = require("browser-sync").create()
chalk = require "chalk"
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
gulp_shell = require "gulp-shell"
gulp_sourcemaps = require "gulp-sourcemaps"
gulp_svgmin = require "gulp-svgmin"
gulp_uglify = require "gulp-uglify"
gulp_util = require "gulp-util"
# gulp_using = require "gulp-using" # Uncomment and npm install for debug
merge_stream = require "merge-stream"
path = require "path"
spawn = require("child_process").spawn


# STATE ###########################################################################################


prod = false
watching = false


# CONFIG ##########################################################################################


# Assets that should just be copied straight from source to public with no processing
basicAssetTypes = "css,gif,jpeg,jpg,json,m4v,min.html,mp3,mp4,pdf,png,swf,woff,woff2"

dev_paths =
  gulp: "dev/*/gulpfile.coffee"
  watch: "dev/**/{dist,pack}/**/*"

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
    watch: "svga/**"

svga_paths =
  coffee: "source/**/*.coffee"
  libs: [
    "node_modules/take-and-make/dist/take-and-make.js"
    "node_modules/pressure/dist/pressure.js"
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
  do gulp_shell.task "open -a Terminal"


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
  cond watching, gulp_changed path, hasChanged: gulp_changed.compareSha1Digest

del = (path)->
  if fs.existsSync path
    for file in fs.readdirSync path
      curPath = path + "/" + file
      if fs.lstatSync(curPath).isDirectory()
        del curPath
      else
        fs.unlinkSync curPath
      null
    fs.rmdirSync path

stream = (glob)->
  cond watching, browser_sync.stream match: glob

stripPack = (path)->
  path.dirname = path.dirname.replace /.*\/pack\//, ''
  path

initMaps = ()->
  cond !prod, gulp_sourcemaps.init()

emitMaps = ()->
  cond !prod, gulp_sourcemaps.write "."

notify = (msg)->
  cond watching, gulp_notify
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
gulp.task "cd-module:basicAssets", ()->
  gulp.src module_paths.basicAssets
    .pipe gulp_rename stripPack
    .pipe changed()
    .pipe gulp.dest "public"
    .pipe stream "**/*.{#{basicAssetTypes},html}"


# Compile coffee in source and asset packs, with sourcemaps in dev and uglify in prod
gulp.task "cd-module:coffee", ()->
  gulp.src module_paths.coffee
    .pipe gulp_natural_sort()
    .pipe initMaps()
    .pipe gulp_concat "scripts.coffee"
    .pipe gulp_coffee()
    .on "error", logAndKillError "COFFEE"
    .pipe emitMaps()
    .pipe gulp.dest "public"
    .pipe stream "**/*.js"
    .pipe notify "Coffee"


gulp.task "cd-module:kit:compile", ()->
  libs = gulp.src module_paths.kit.libs
    .pipe gulp.dest "public/_libs"
  packHtml = gulp.src module_paths.kit.packHtml
    .pipe gulp_natural_sort()
  gulp.src module_paths.kit.index
    .pipe gulp_kit()
    .on "error", logAndKillError "KIT"
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
    .pipe gulp_replace "bower_components", "node_modules"
    .pipe gulp.dest "source"


# Compile scss in source and asset packs, with sourcemaps in dev and autoprefixer in prod
gulp.task "cd-module:scss", ()->
  gulp.src module_paths.scss
    .pipe gulp_natural_sort()
    .pipe initMaps()
    .pipe gulp_concat "styles.scss"
    .pipe gulp_sass
      precision: 2
    .on "error", logAndKillError "SCSS", false
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
    .pipe gulp_svgmin (file)-> {full: true, plugins: cd_module_svg_plugins}
    .pipe gulp.dest "public"


# TASKS: SVGA COMPILATION #########################################################################


# This task MUST be idempotent, since it overwrites the original file
svga_beautify_svg = (cwd, svgName, dest)-> ()->
  fixFlashWeirdness gulp.src "#{cwd}/#{svga_paths.svg}", ignore: "source/icon.svg"
    .pipe changed cwd + "/source"
    .pipe gulp_replace /<svg .*?(width=.+? height=.+?").*?>/, '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" xmlns:xlink="http://www.w3.org/1999/xlink" font-family="Lato, sans-serif" $1>'
    .on "error", logAndKillError "SVG"
    .pipe gulp_svgmin
      full: true
      js2svg:
        pretty: true
        indent: "  "
      plugins: svg_plugins
    .pipe gulp.dest cwd + "/source"


svga_coffee_source = (cwd, svgName, dest)-> ()->
  gulp.src cwd + "/" + svga_paths.coffee
    .pipe gulp_natural_sort()
    .pipe initMaps()
    .pipe gulp_concat "source.coffee"
    .pipe gulp_coffee()
    .on "error", logAndKillError "COFFEE"
    .pipe gulp_rename (path)->
      path.basename = svgName
      path
    .pipe emitMaps()
    .pipe gulp.dest dest
    .pipe stream "**/*.js"
    .pipe notify "Coffee"


svga_wrap_svg = (cwd, svgName, dest)-> ()->
  libs = gulp.src svga_paths.libs
    .pipe gulp.dest "#{dest}/_libs"
  svgSource = gulp.src "#{cwd}/#{svga_paths.svg}", ignore: "source/icon.svg"
    .pipe gulp_replace "</defs>", "</defs>\n<g id=\"root\">"
    .pipe gulp_replace "</svg>", "</g>\n</svg>"
  gulp.src svga_paths.wrapper
    .pipe gulp_inject svgSource, name: "source", transform: fileContents
    .pipe gulp_inject libs, name: "libs", ignorePath: dest, addRootSlash: false
    .pipe gulp_replace "<script src=\"_libs", "<script defer src=\"_libs"
    .pipe gulp_replace "<script defer src=\"source.js", "<script defer src=\"#{svgName}.js"
    .pipe cond prod, gulp_htmlmin
      collapseWhitespace: true
      collapseBooleanAttributes: true
      collapseInlineTagWhitespace: true
      includeAutoGeneratedTags: false
      removeComments: true
    .on "error", logAndKillError "SVG"
    .pipe gulp_rename (path)->
      path.basename = svgName
      path
    .pipe gulp.dest dest
    .pipe notify "SVG"


gulp.task "svga:beautify-svg", svga_beautify_svg ".", "index", "public"
gulp.task "svga:coffee:source", svga_coffee_source ".", "index", "public"
gulp.task "svga:wrap-svg", svga_wrap_svg ".", "index", "public"


# TASKS: SYSTEM ###################################################################################


gulp.task "del:public", (cb)->
  del "public"
  cb()


gulp.task "del:deploy", (cb)->
  del "deploy"
  cb()


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
  js = gulp.src "public/**/*.js"
    .pipe gulp_uglify()
  css = gulp.src ["public/**/*.css", "!public/fonts/**/*.css"]
    .pipe gulp_autoprefixer
      browsers: "Android >= 4.4, Chrome >= 44, ChromeAndroid >= 44, Edge >= 12, ExplorerMobile >= 11, IE >= 11, Firefox >= 40, iOS >= 9, Safari >= 9"
      cascade: false
      remove: false
    .pipe gulp_clean_css
      level: 2
      rebaseTo: "public"
  other = gulp.src ["public/**","!public/**/*.{js,css}"]
  merge_stream js, css, other
    .pipe gulp_rev_all.revision
      transformPath: (rev, source, path)-> # Applies to file references inside HTML/CSS/JS
        rev.replace /.*\//, ""
      transformFilename: (file, hash)-> # Applies to the files themselves
        name = file.revHash + file.extname
        gulp_shell.task("mkdir -p deploy/index && touch deploy/index/#{name}")() if file.revPathOriginal.indexOf("/public/index.html") > 0
        name
    .pipe gulp_rename (path)->
      path.dirname = ""
      path
    .pipe gulp.dest "deploy/all"


gulp.task "serve", (cb)->
  browser_sync.init
    ghostMode: false
    notify: false
    server: baseDir: "public"
    ui: false
    watchOptions: ignoreInitial: true
  cb()


# TASKS: MODULE MAIN ##############################################################################

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

gulp.task "cd-module:svga",
  gulp.series "cd-module:svga:beautify", "cd-module:svga:coffee", "cd-module:svga:wrap"


gulp.task "cd-module:watch", (cb)->
  watching = true
  gulp.watch module_paths.basicAssets, gulp.series "cd-module:basicAssets"
  gulp.watch module_paths.coffee, gulp.series "cd-module:coffee"
  gulp.watch dev_paths.watch, gulp.series "dev"
  gulp.watch module_paths.kit.watch, gulp.series "cd-module:kit:compile", "reload"
  gulp.watch module_paths.scss, gulp.series "cd-module:scss"
  gulp.watch module_paths.svg, gulp.series "cd-module:svg", "reload"
  gulp.watch module_paths.svga.watch, gulp.series "cd-module:svga", "reload"
  cb()


gulp.task "cd-module:recompile",
  gulp.series "cd-module:svga-check", "del:public", "dev", "cd-module:kit:fix", "cd-module:basicAssets", "cd-module:coffee", "cd-module:scss", "cd-module:svg", "cd-module:svga", "cd-module:kit:compile"


gulp.task "cd-module:prod",
  gulp.series "prod:setup", "cd-module:recompile", "del:deploy", "rev"


gulp.task "cd-module:dev",
  gulp.series "dev:watch", "cd-module:recompile", "cd-module:watch", "serve"


# TASKS: SVGA MAIN ################################################################################


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
