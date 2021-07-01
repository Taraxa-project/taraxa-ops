FROM node:14-slim

WORKDIR /app
COPY package.json ./
COPY yarn.lock ./

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

RUN yarn install
COPY . .

RUN yarn run build

CMD ["yarn", "start"]