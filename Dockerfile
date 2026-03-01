ARG METABASE_VERSION=v0.58.8
FROM metabase/metabase:${METABASE_VERSION}@sha256:2ec9dc9f727be1eb9bf4b9438932f7a235b00f14649a86a09513f7988221f692

USER root

# Copy branding assets and patch script
COPY assets/ /tmp/assets/
COPY patch-branding.sh /tmp/patch-branding.sh

# Single RUN: install zip, verify JAR paths, copy assets, patch bundles, clean up
RUN apk add --no-cache zip \
    && mkdir -p /tmp/branding/frontend_client/app/assets/img \
    && cp /tmp/assets/logo.svg /tmp/assets/favicon.ico /tmp/assets/favicon-16x16.png \
       /tmp/assets/favicon-32x32.png /tmp/assets/apple-touch-icon.png \
       /tmp/assets/loading_favicon.gif \
       /tmp/branding/frontend_client/app/assets/img/ \
    && cp /tmp/assets/favicon.ico /tmp/branding/frontend_client/favicon.ico \
    && for f in \
         frontend_client/app/assets/img/logo.svg \
         frontend_client/app/assets/img/favicon.ico \
         frontend_client/app/assets/img/favicon-16x16.png \
         frontend_client/app/assets/img/favicon-32x32.png \
         frontend_client/app/assets/img/apple-touch-icon.png \
         frontend_client/app/assets/img/loading_favicon.gif; do \
       unzip -p /app/metabase.jar "$f" > /dev/null 2>&1 || \
         (echo "ERROR: $f not found in metabase.jar — JAR structure may have changed" && exit 1); \
    done \
    && chmod +x /tmp/patch-branding.sh && /tmp/patch-branding.sh \
    && (zip -d /app/metabase.jar 'META-INF/*.SF' 'META-INF/*.RSA' 2>/dev/null || true) \
    && rm -rf /tmp/branding /tmp/patch-branding.sh /tmp/assets \
    && apk del zip

WORKDIR /app

# Drop back to non-root user (Metabase upstream default)
USER 2000

LABEL org.opencontainers.image.title="Metabase Atomtech"
LABEL org.opencontainers.image.description="Metabase OSS with Atomtech branding"
LABEL org.opencontainers.image.vendor="Atomtech Consulting"
