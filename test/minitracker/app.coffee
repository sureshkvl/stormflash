#start the stormtracker web application
{@app} = require('zappajs') 5555, ->
    @configure =>
        @use 'bodyParser', 'methodOverride', @app.router, 'static'
        @set 'basepath': '/v1.0'

    @configure
        development: => @use errorHandler: {dumpExceptions: on, showStack: on}
        production: => @use 'errorHandler'

    @enable 'serve jquery', 'minify'
    @include './lib/tracker'
