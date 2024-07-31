const path = require('path')
const webpack = require('webpack')

const mode =
  process.env.NODE_ENV === 'development' ? 'development' : 'production'

module.exports = {
  mode,
  devtool: 'source-map',
  entry: {
    bundle: './app/javascript/application.js',
  },
  output: {
    filename: '[name].js',
    sourceMapFilename: '[file].map',
    path: path.resolve(__dirname, 'app/assets/builds'),
  },
  module: {
    rules: [
      {
        test: /\.jsx?$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader',
          options: {
            envName: mode,
            presets: ['@babel/preset-react'],
            env: {
              production: {
                plugins: ['transform-react-remove-prop-types'],
              },
            },
          },
        },
      },
    ],
  },
  plugins: [
    new webpack.optimize.LimitChunkCountPlugin({
      maxChunks: 1,
    }),
    new webpack.DefinePlugin({
      // prettier-ignore
      AIRBRAKE_PROJECT_ID: JSON.stringify(process.env.AIRBRAKE_PROJECT_ID || null),
      AIRBRAKE_API_KEY: JSON.stringify(process.env.AIRBRAKE_API_KEY || null),
    }),
  ],
  externals: {
    jquery: '$',
  },
}
