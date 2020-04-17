const tk = require("timekeeper");
const AWS = require("aws-sdk");

const s3 = new AWS.S3();

const getTruncatedTime = () => {
	const currentTime = new Date();
	const d = new Date(currentTime);

	d.setMinutes(Math.floor(d.getMinutes() / 5) * 5);
	d.setSeconds(0);
	d.setMilliseconds(0);

	return d;
};

module.exports.handler = async (event) => {
	const pathPattern = new RegExp("^/(default|(?<truncated>truncated))/tab(?<tab>\\d+)$");

	if (event.path === "/") {
		return {
			statusCode: 200,
			headers: {
				"Content-Type": "text/html",
			},
			body: `
<html>
	<body>
		<h3><a href="default/tab1">getSignedUrl with current time</a></h3>
		<h3><a href="truncated/tab1">getSignedUrl with truncated time</a></h3>
	</body>
</html>
			`,
		};
	}else if (event.path.match(pathPattern)) {
		const {truncated, tab} = event.path.match(pathPattern).groups;

		const url = await (async () => {
			if (truncated !== undefined) {
				return tk.withFreeze(getTruncatedTime(), () => {
					return s3.getSignedUrl(
						"getObject",
						{
							Bucket: process.env.BUCKET,
							Key: "cat.jpg"
						}
					);
				});
			}else {
				return s3.getSignedUrlPromise(
					"getObject",
					{
						Bucket: process.env.BUCKET,
						Key: "cat.jpg"
					}
				);
			}
		})();
		return {
			statusCode: 200,
			headers: {
				"Content-Type": "text/html",
			},
			body: `
<html>
	<body>
		<h3><a href="..">back</a></h3>
		${tab !== "1" ? "<a href=\"tab1\">tab 1</a>" : "<span>tab 1 </span>"}
		${tab !== "2" ? "<a href=\"tab2\">tab 2</a>" : "<span>tab 2 </span>"}
		<h1>tab ${tab}</h1>
		<p>Image:</p>
		<img src="${url}">
	</body>
</html>
			`
		};
	}
};

