# OpenAccessType
## Open Access type from various sources, notably Unpaywall

OpenAccessType provides a script and a set of plug-ins to determine the Open Access type
(gold, green, ...) of an eprint.

Sources for the calculation can be configured in cfg.d/z_open_access.pl

* Unpaywall
* JDB (Journal Database of University of Zurich, can currently only be used in this
environment, see below)

The OpenAccess.pm plug-in provides a generic module to call various sources, including the
EPrints repository itself. Sources are provided as child modules of the OpenAccess plug-in. 
It takes the return data and then determines the Open Access type according to a general
logic that takes into account the priority of the sources, and also resolves conflicts. 


The OA type is not a static quantity - it can change when e.g. a document or a document 
property is changed. For example, when embargo is lifted. For this, a series of trigger 
methods are available in  cfg.d/z_open_access.pl that call event methods of the 
OpenAccessEvent module.

## Sources

All sources should return results to OpenAccess.pm using the following data structure:

{
		'error' => $error,
		'oa_type' => $oa_type,
		'is_doaj' => $is_doaj,
		'journal_is_hybrid' => $is_hybrid,
		'journal' => $journal_title,
		'publisher' => $publisher,
		'apc_currency' => $apc_currency,
		'apc_fee' => $apc_fee,
		'apc_year' => $apc_year,
		'license' => $license,
		'url' => $url,
		'driver_version' => $driver_version,
		'remark' => $remark,	
}

Not all elements are required or are available (e.g. the apc_* elements). 
OpenAccess.pm takes what it gets, combines the data into a single data structure according
to the priority of the source specified in cfg.d/z_open_access.pl , and points out 
conflicts.


### Unpaywall

The Unpaywall plug-in can be used as is. Please edit the e-mail address that is needed
as parameter for the Unpaywall Data API in cfg.d/z_unpaywall_api.pl 


### JDB

The JDB plug-in provided here is for documentation purposes only. You should disable it
in cfg.d/z_open_access.pl .

Journal Database (www.jdb.uzh.ch) provides information about the copyright and refereed 
situation as well as APCs of various journals/series and publishers that are used in 
University of Zurich's Open Repository and Archive ZORA. JDB lists about 30K 
journals/series and 10K publishers. It is fed by data of ZORA, Ulrichsweb, Sherpa/RoMEO, 
EZB, DOAJ, publisher APC lists and many more. 
Sample records can be inspected at
http://www.jdb.uzh.ch/id/eprint/18222/ (Gold OA journal) and 
http://www.jdb.uzh.ch/id/eprint/37547/ (Hybrid journal)

## Notes on installation

The indexer must be restarted so that the OpenAccessEvent module is loaded and processed.


## Additional parts for IRStats2

lib/plugins/Stats, cfg.d/z_stats.pl and cfg/static/javascript/auto/90_irstats.js
provide examples for processing and displaying the Open Access type in IRStats2. These 
are tailored for the ZORA repository and you must adapt them to your needs.
Example: http://www.zora.uzh.ch/cgi/stats/report/pubyear/2016/open_access

cfg/static/javascript/auto/90_irstats.js was adapted to the responsive interface and improved
accessibility of ZORA and may have code parts that do not fit your IRStats2 installation. 
Please just consider the changes that are marked as UZH CHANGE ZORA-627. This part
changes the colors of the pie chart slices.

