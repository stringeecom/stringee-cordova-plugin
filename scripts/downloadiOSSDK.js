#!/usr/bin/env node

module.exports = function (context) {
    var IosSDKVersion = "StringeeSDK-iOS-1.2.9";
    var downloadFile = require('./downloadFile.js'),
        exec = require('./exec/exec.js'),
        Q = context.requireCordovaModule('q'),
        deferral = new Q.defer();
    console.log('Downloading Stringee iOS SDK');
    downloadFile('https://static.stringee.com/sdk/' + IosSDKVersion + '.zip',
        './' + IosSDKVersion + '.zip', function (err) {
            if (!err) {
                console.log('downloaded');
                exec('unzip ./' + IosSDKVersion + '.zip', function (err, out, code) {
                    console.log('expanded');
                    var frameworkDir = context.opts.plugin.dir + '/src/ios/';
                    exec('mv ./' + IosSDKVersion + '/Stringee.framework ' + frameworkDir, function (err, out, code) {
                        console.log('moved Stringee.framework into ' + frameworkDir);
                        exec('rm -r ./' + IosSDKVersion, function (err, out, code) {
                            console.log('Removed extracted dir');
                            exec('rm ./' + IosSDKVersion + '.zip', function (err, out, code) {
                                console.log('Removed downloaded SDK');
                                exec('rm -r ./' + '__MACOSX', function (err, out, code) {
                                    console.log('Removed __MACOSX folder');
                                    deferral.resolve();
                                });
                            });
                        });
                    });
                });
            }
        });
    return deferral.promise;
};
