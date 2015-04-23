upload:
	rsync -avz yarn.{n3,ttl} hosting_ustalov@neon.locum.ru:~/projects/nlpub-store/htdocs/metarulex/
	rsync -avz ruthes/ruthes-lite.n3 ruthes-lite.ttl hosting_ustalov@neon.locum.ru:~/projects/nlpub-store/htdocs/metarulex/
	rsync -avz unldc/unldc.n3 unldc.ttl hosting_ustalov@neon.locum.ru:~/projects/nlpub-store/htdocs/metarulex/
ttl:
	rapper -i turtle -o turtle ruthes/ruthes-lite.n3 >ruthes-lite.ttl
	rapper -i turtle -o turtle yarn.n3 >yarn.ttl
	rapper -i turtle -o turtle unldc/unldc.n3 >unldc.ttl
