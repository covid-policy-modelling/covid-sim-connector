import { pino } from 'pino'

export const logger = pino({
  name: 'covid-sim-connector',
  level: 'info',
})
