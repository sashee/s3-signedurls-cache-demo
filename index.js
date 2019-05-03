const express = require("express");
const tk = require("timekeeper");
const AWS = require("aws-sdk");

const s3 = new AWS.S3();

const app = express();

app.set("view engine", "pug");

const getTruncatedTime = () => {
	const currentTime = new Date();
	const d = new Date(currentTime);

	d.setMinutes(Math.floor(d.getMinutes() / 10) * 10);
	d.setSeconds(0);
	d.setMilliseconds(0);

	return d;
};

app.get("/", (req, res) => {
	res.render("index");
});

app.get("/default/*", (req, res) => {
	const url = s3.getSignedUrl(
		"getObject",
		{
			Bucket: process.env.BUCKETNAME,
			Key: "cat.jpg"
		}
	);

	res.render("test", {url: req.url, lolcat: url, base: "default"});
});

app.get("/truncated/*", (req, res) => {
	const url = tk.withFreeze(getTruncatedTime(), () => {
		return s3.getSignedUrl(
			"getObject",
			{
				Bucket: process.env.BUCKETNAME,
				Key: "cat.jpg"
			}
		);
	});

	res.render("test", {url: req.url, lolcat: url, base: "truncated"});
});

app.listen(3000);
