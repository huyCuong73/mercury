package integration

import (
	"testing"

	"github.com/stretchr/testify/suite"

	evm "github.com/huyCuong73/mercury"
	"github.com/huyCuong73/mercury/tests/integration/eip712"
	testapp "github.com/huyCuong73/mercury/testutil/app"
)

func TestEIP712TestSuite(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.IntegrationNetworkApp](CreateEvmd, "evm.IntegrationNetworkApp")
	s := eip712.NewTestSuite(create, false)
	suite.Run(t, s)

	// Note that we don't test the Legacy EIP-712 Extension, since that case
	// is sufficiently covered by the AnteHandler tests.
	s = eip712.NewTestSuite(create, true)
	suite.Run(t, s)
}
