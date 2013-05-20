#!/usr/bin/env node

var docopt = require('docopt');
var path = require('path');
var should = require('should');
var fs = require('fs');
var FileQueue = require('FileQueue');
var fq = new FileQueue();
var J = path.join, R = path.resolve;
var async = require('async');

// ------------- START OPTIONS
// JS docopt does not support:
//  * multiple arguments with elipsis (...)
//  * [options] keyword, later defined
var doc = '\
Usage:																	\n\
	' + __filename + ' <dir> [--parallel=<num>] [-v --verbose]			\n\
	' + __filename + ' (-h | --help | --version)				        \n\
																		\n\
We run the "Directory Processor" benchmark:								\n\
  1.  Read the given directory											\n\
  2.  Rename each file to include its sequence number in the			\n\
      alphabetical list.												\n\
  3.  Open each file and strip out all the markup "<[^>]*>.				\n\
																		\n\
Options:																\n\
	-h --help   Display this help message and exit 0					\n\
	--verbose	Should we be verbose?									\n\
';

var package_json = require('./package.json');

var options = docopt.docopt(doc, {argv: process.argv.slice(2), help: true,
									version: package_json["version"]});
options["--verbose"] = options["-v"] || options["--verbose"];
									
if (options["--verbose"] > 1) {
	console.warn("We are very verbose!!!");
}

options.should.have.property('<dir>');

var handleErr = function(err, cb) {
	if (cb) { return cb(err); }
	throw err;
};

var transform_re = /<[^>]*>/g;

var fileProcessor = function(fp, seqno, cb) {
	//console.dir('processing file: ' + fp);
	// Rename the file
	var dir = path.dirname(path);
	var ext = path.extname(fp);
	var new_base = path.basename(fp, ext) + '-' + seqno;
	var new_fp = J(dir, new_base + ext);
	fs.rename(fp, new_fp, function(err) {
		if (err) return handleErr(err, cb);
		// Open the file, read whole thing into mem. and remove the HTML tags
		fq.readFile(new_fp, 'utf8', function(err, content) {
			new_content = content.replace(transform_re, '');
			// Write the new tagless stuff back out
			fq.writeFile(new_fp, new_content, function(err) {
				return handleErr(err, cb);
			});
		});
	});
}

var directoryProcessor = function(dir, parallel) {
	if (parallel == NaN) throw "invalid parallel arg";
	fs.readdir(dir, function(err, listing) {
		should.ifError(err);
		var processors = [];
		for (var i = 0; i < listing.length; i++) {
			processors.push((function (i2) { return function(cb) {
				fileProcessor(J(dir, listing[i2]), i2+1, cb);
			}; })(i));
		}
		async.parallelLimit(processors, parallel, function(err, results) {
			if (err) return handleErr(err, null);
		});
	});
}

var main = function () {
	directoryProcessor(options['<dir>'], parseInt(options['--parallel']));

	return 0;
};

main();
