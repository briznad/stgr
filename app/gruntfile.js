/**
 * Grunt configuration for stgr
 **/
module.exports = function(grunt) {
    'use strict';

    // load all plugins
    require('matchdep').filterDev('grunt-*').forEach(function(obj) {
        console.log(obj);
        grunt.loadNpmTasks(obj);
    });

    // project configuration
    grunt.initConfig({
        config: {
            sassInput: 'assets/sass/',
            coffeeInput: 'assets/coffee/',
            jsRawIO: 'assets/js/',
            cssOutput: 'webroot/assets/css/',
            jsOutput: 'webroot/assets/js/'
        },

        clean: {
            css: {
                src: ['<%= config.cssOutput %>*.css'],
                options: {
                    force: true
                }
            },
            js: {
                src: ['<%= config.jsRawIO %>*.js', '<%= config.jsOutput %>*.js'],
                options: {
                    force: true
                }
            }
        },

        sass: {
            prod: {
                options: {
                    includePaths: ['<%= config.sassInput %>*/'],
                    outputStyle: 'nested'
                },
                files: {
                    '<%= config.cssOutput %>style.css': '<%= config.sassInput %>style.scss'
                }
            }
        },

        autoprefixer: {
            options: {
                browsers: ['last 5 version', 'ie >= 8']
            },
            prod: {
                src: '<%= config.cssOutput %>style.css'
            }
        },

        cssmin: {
            prod: {
                files: {
                    '<%= config.cssOutput %>style.min.css': '<%= config.cssOutput %>style.css'
                }
            }
        },

        coffeelint: {
            dist: {
                files: {
                    src: ['<%= config.coffeeInput %>*.coffee']
                },
                options: {
                    max_line_length: {
                        level: "ignore"
                    }
                }
            }
        },

        coffee: {
            options: {
                bare: true
            },
            glob_to_multiple: {
                expand: true,
                flatten: true,
                cwd: '<%= config.coffeeInput %>',
                src: ['*.coffee'],
                dest: '<%= config.jsRawIO %>',
                ext: '.js'
            }
        },

        jshint: {
            options: {
                boss: true,
                browser: true,
                curly: true,
                eqeqeq: true,
                eqnull: true,
                immed: false,
                latedef: true,
                newcap: true,
                noarg: true,
                node: true,
                sub: true,
                trailing: true,
                laxcomma: true,
                laxbreak: true,
                undef: true,
                debug: true,
                globals: {
                    _: true,
                    $: true,
                    jQuery: true,
                    _gaq: true,
                    Modernizr: true,
                    Davis: true
                }
            },
            gruntfile: {
                src: 'gruntfile.js'
            },
            src: {
                src: ['<%= config.jsRawIO %>*.js']
            }
        },

        concat: {
            options: {
                stripBanners: true,
                separator: ';'
            },
            js: {
                src: [
                    '<%= config.jsRawIO %>plugins/jquery-*.js', // jQuery must be the first plugin loaded, as it's depended by jQuery plugins as well as Davis.js
                    '<%= config.jsRawIO %>plugins/jquery.*.js',
                    '<%= config.jsRawIO %>plugins/davis.js',
                    '<%= config.jsRawIO %>plugins/underscore.js',
                    '<%= config.jsRawIO %>*.js'
                ],
                dest: '<%= config.jsOutput %>do.js'
            }
        },

        uglify: {
            options: {
                beautify: false,
                report: false,
                mangle: true,
                compress: {
                    warnings: true
                }
            },
            js: {
                files: {
                    '<%= config.jsOutput %>do.min.js': '<%= config.jsOutput %>do.js'
                }
            }
        },

        watch: {
            // whenever a coffee file is changed, compile it
            coffee: {
                files: '<%= config.coffeeInput %>**/*.coffee',
                tasks: ['clean:js', 'coffeelint', 'coffee', 'jshint', 'concat', 'uglify']
            },
            // whenever a scss file is changed, compile it
            sass: {
                files: '<%= config.sassInput %>**/*.scss',
                tasks: ['clean:css', 'sass', 'autoprefixer', 'cssmin']
            }
        }
    });

    // default task.
    grunt.registerTask('default', ['clean', 'coffeelint', 'coffee', 'jshint', 'concat', 'uglify', 'sass', 'autoprefixer', 'cssmin']);
};