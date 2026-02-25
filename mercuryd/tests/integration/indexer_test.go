package integration

import (
	"testing"

	evm "github.com/huyCuong73/mercury"
	"github.com/huyCuong73/mercury/tests/integration/indexer"
	testapp "github.com/huyCuong73/mercury/testutil/app"
)

func TestKVIndexer(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.IntegrationNetworkApp](CreateEvmd, "evm.IntegrationNetworkApp")
	indexer.TestKVIndexer(t, create)
}
