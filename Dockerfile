ARG SDKVERSION=5.0-alpine
ARG RUNTIMEVERSION=5.0-alpine

FROM mcr.microsoft.com/dotnet/aspnet:$RUNTIMEVERSION AS base
ARG DAMSELFLY_VERSION
WORKDIR /app
EXPOSE 6363

# First, build the desktop apps
# FROM electronuserland/builder:wine as desktop
# ARG DAMSELFLY_VERSION
# RUN echo Damselfly Desktop version ${DAMSELFLY_VERSION}
# RUN apt-get update && apt-get install -y zip
# COPY ./Damselfly.Desktop /src
# WORKDIR "/src"
# RUN yarn && yarn install && yarn version --new-version ${DAMSELFLY_VERSION} && yarn dist

# Now build the app itself
FROM mcr.microsoft.com/dotnet/sdk:$SDKVERSION AS build
ARG DAMSELFLY_VERSION
RUN echo Damselfly Server version ${DAMSELFLY_VERSION}
WORKDIR /src
COPY Damselfly.Web/Damselfly.Web.csproj Damselfly.Web/
COPY Damselfly.Core/Damselfly.Core.csproj Damselfly.Core/
COPY Nuget.Config . 
RUN dotnet restore --configfile Nuget.Config "Damselfly.Web/Damselfly.Web.csproj"
COPY . .
WORKDIR "/src/Damselfly.Web"
RUN dotnet build "Damselfly.Web.csproj" -c Release -o /app/build /p:Version=${DAMSELFLY_VERSION}

# Now run the publish
FROM build AS publish
ARG DAMSELFLY_VERSION
RUN dotnet publish "Damselfly.Web.csproj" -c Release -o /app/publish  -r alpine-x64 /p:Version=${DAMSELFLY_VERSION} /p:PublishReadyToRun=true 

# Assemble the final image
FROM base AS final
ARG DAMSELFLY_VERSION

# Copy the desktop apps into the image (these are built outside docker at the moment)
WORKDIR /wwwroot/desktop
COPY ./Damselfly.Web/wwwroot/desktop/damselfly-mac.zip .
COPY ./Damselfly.Web/wwwroot/desktop/damselfly-win.zip .
COPY ./Damselfly.Web/wwwroot/desktop/damselfly-linux.appimage .

WORKDIR /app
# This may re-copy the desktop/* apps, but who cares.
COPY --from=publish /app/publish .

# Copy the entrypoint script
COPY ./damselfly-entrypoint.sh /
RUN ["chmod", "+x", "/damselfly-entrypoint.sh"]
ADD VERSION .

# Add Microsoft fonts that'll be used for watermarking
RUN apk add --no-cache msttcorefonts-installer fontconfig && update-ms-fonts

# Add ExifTool
RUN apk --update add exiftool && rm -rf /var/cache/apk/*

# Make and install exiftool if we want a newer version
# ENV EXIFTOOL_VERSION=12.10
# RUN apk add --no-cache perl make
# RUN cd /tmp \
# 	&& wget http://www.sno.phy.queensu.ca/~phil/exiftool/Image-ExifTool-${EXIFTOOL_VERSION}.tar.gz \
# 	&& cd Image-ExifTool-${EXIFTOOL_VERSION} \
# 	&& tar -zxvf Image-ExifTool-${EXIFTOOL_VERSION}.tar.gz \
# 	&& perl Makefile.PL \
# 	&& make test \
# 	&& make install \
# 	&& cd .. \
# 	&& rm -rf Image-ExifTool-${EXIFTOOL_VERSION}

ENTRYPOINT ["sh","/damselfly-entrypoint.sh"]
