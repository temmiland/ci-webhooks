# Use minimal Alpine image
FROM alpine:latest

# Install jq and bash (no cache)
RUN apk add --no-cache jq bash

# Set working directory
WORKDIR /app

# Run the generator script
CMD ["bash", "generate_env.sh"]
