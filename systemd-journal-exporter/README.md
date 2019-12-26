
basic prometheus exporter as a "Counter" from systemd logs.

after enabling systemd application service unit, check with http://localhost:9600/metrics

and add an exporter to prometheus configuration, for example:
```
  - job_name: exporter1
    scrape_interval: 30s
    scrape_timeout:  10s
    static_configs:
      - targets:  
        - 127.0.0.5:9600
        labels:
          env: logmetric1
```  
