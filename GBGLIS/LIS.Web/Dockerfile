FROM node:10.15.3-alpine as builder
RUN mkdir /app
WORKDIR /app
COPY package.json /app/package.json
RUN npm install
COPY . /app

# ARG BRANCH
# ARG DOMAIN
# RUN cp src/environments/environment.feature.ts.tmpl src/environments/environment.feature.ts \
#     && sed -i -e "s@{{BRANCH}}@${BRANCH}@g" src/environments/environment.feature.ts \
#     && sed -i -e "s@{{DOMAIN}}@${DOMAIN}@g" src/environments/environment.feature.ts
RUN ./node_modules/@angular/cli/bin/ng build --prod -c feature

FROM dimag/nginx:web
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]