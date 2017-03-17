FROM samchang/webase

ENV MARIA_DATABASE_NAME test

COPY web /root/web
COPY handle /root/handle
COPY database /root/database
